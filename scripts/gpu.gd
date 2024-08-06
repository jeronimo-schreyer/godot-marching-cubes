@tool
extends MeshInstance3D


var rd = RenderingServer.create_local_rendering_device()
var pipeline : RID
var shader : RID
var buffers: Array
var uniform_set : RID
const uniform_set_index : int = 0

var output

@export var ISO:float = 0.1
@export var DATA:Texture3D
@export var FLAT_SHADED:bool = false


@export var GENERATE: bool:
	set(value):
		var time = Time.get_ticks_msec()
		compute()
		var elapsed = (Time.get_ticks_msec()-time)/1000.0
		print("Terrain generated in: " + str(elapsed) + "s")


# Called when the node enters the scene tree for the first time.
func _ready():
	init_compute()
	setup_bindings()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _notification(type):
	if type == NOTIFICATION_PREDELETE:
		release()


func release():
	for b in buffers:
		rd.free_rid(b)
	buffers.clear()
#
	rd.free_rid(pipeline)
	rd.free_rid(shader)
	rd.free()


func get_params():
	var voxel_grid_size := Vector3(DATA.get_width(), DATA.get_height(), DATA.get_depth())
	var voxel_grid := MarchingCubes.VoxelGrid.new(voxel_grid_size)
	voxel_grid.set_data(DATA)

	var params = PackedFloat32Array()
	params.append(voxel_grid_size.x)
	params.append(voxel_grid_size.y)
	params.append(voxel_grid_size.z)
	params.append(ISO)
	params.append(int(FLAT_SHADED))

	params.append_array(voxel_grid.data)

	return params


func init_compute():
	# Create shader and pipeline
	var shader_file = load("res://shaders/marching_cubes.glsl")
	var shader_spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)


func setup_bindings():
	# Create the input params buffer
	var input = get_params()
	var input_bytes = input.to_byte_array()
	buffers.push_back(rd.storage_buffer_create(input_bytes.size(), input_bytes))

	var input_params_uniform := RDUniform.new()
	input_params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	input_params_uniform.binding = 0
	input_params_uniform.add_id(buffers[0])

	# Create counter buffer

	var counter_bytes = PackedFloat32Array([0]).to_byte_array()
	buffers.push_back(rd.storage_buffer_create(counter_bytes.size(), counter_bytes))

	var counter_uniform = RDUniform.new()
	counter_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	counter_uniform.binding = 1
	counter_uniform.add_id(buffers[1])

	# Create the triangles buffer
	var total_cells = DATA.get_width() * DATA.get_height() * DATA.get_depth()
	var vectors = PackedColorArray()
	vectors.resize(total_cells * 5 * 3) # 5 triangles max per cell, 3 vertices per triangle
	var vectors_bytes = vectors.to_byte_array()
	buffers.push_back(rd.storage_buffer_create(vectors_bytes.size(), vectors_bytes))

	var vectors_uniform := RDUniform.new()
	vectors_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vectors_uniform.binding = 2
	vectors_uniform.add_id(buffers[2])

	# Create the LUT buffer
	var lut_array = PackedInt32Array()
	for i in range(MarchingCubes.LUT.size()):
		lut_array.append_array(MarchingCubes.LUT[i])
	var lut_array_bytes = lut_array.to_byte_array()
	buffers.push_back(rd.storage_buffer_create(lut_array_bytes.size(), lut_array_bytes))

	var lut_uniform := RDUniform.new()
	lut_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	lut_uniform.binding = 3
	lut_uniform.add_id(buffers[3])

	uniform_set = rd.uniform_set_create([
		input_params_uniform,
		counter_uniform,
		vectors_uniform,
		lut_uniform,
	], shader, uniform_set_index)


func compute():
	# Update input buffers and clear output ones
	# This one is actually not always needed. Comment to see major speed optimization
	var time_send: int = Time.get_ticks_usec()
	var input = get_params()
	var input_bytes = input.to_byte_array()
	rd.buffer_update(buffers[0], 0, input_bytes.size(), input_bytes)

	var total_cells = DATA.get_width() * DATA.get_height() * DATA.get_depth()
	var vectors = PackedColorArray()
	vectors.resize(total_cells * 5 * 3) # 5 triangles max per cell, 3 vertices per triangle
	var vectors_bytes = vectors.to_byte_array()

	var counter_bytes = PackedFloat32Array([0]).to_byte_array()
	rd.buffer_update(buffers[1], 0, counter_bytes.size(), counter_bytes)
	print("Time to update buffer: " + Utils.parse_time(Time.get_ticks_usec() - time_send))

	# Dispatch compute and uniforms
	time_send = Time.get_ticks_usec()
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, uniform_set_index)
	rd.compute_list_dispatch(compute_list, DATA.get_width() / 8, DATA.get_height() / 8, DATA.get_depth() / 8)
	rd.compute_list_end()
	print("Time to dispatch uniforms: " + Utils.parse_time(Time.get_ticks_usec() - time_send))

	# Submit to GPU and wait for sync
	time_send = Time.get_ticks_usec()
	rd.submit()
	rd.sync()
	print("Time to submit and sync: " + Utils.parse_time(Time.get_ticks_usec() - time_send))

	# Read back the data from the buffer
	time_send = Time.get_ticks_usec()
	var total_triangles = rd.buffer_get_data(buffers[1]).to_int32_array()[0]
	var output_array := rd.buffer_get_data(buffers[2]).to_float32_array()
	print("Time to read back buffer: " + Utils.parse_time(Time.get_ticks_usec() - time_send))

	time_send = Time.get_ticks_usec()
	output = PackedVector3Array()
	for i in range(0, total_triangles * 12, 12): # Each triangle spans for 12 floats
		output.push_back(Vector3(output_array[i+0], output_array[i+1], output_array[i+2]))
		output.push_back(Vector3(output_array[i+4], output_array[i+5], output_array[i+6]))
		output.push_back(Vector3(output_array[i+8], output_array[i+9], output_array[i+10]))
	print("Time iterate vertices: " + Utils.parse_time(Time.get_ticks_usec() - time_send))
	print("Total vertices ", output.size())

	time_send = Time.get_ticks_usec()
	# draw
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	if FLAT_SHADED:
		surface_tool.set_smooth_group(-1)

	for vert in output:
		surface_tool.add_vertex(vert)

	surface_tool.generate_normals()
	surface_tool.index()
	call_deferred("set_mesh", surface_tool.commit())
	print("Time to create surface tool: " + Utils.parse_time(Time.get_ticks_usec() - time_send))
