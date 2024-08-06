@tool
extends MeshInstance3D

const POINTS = [
	Vector3i(0, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(1, 0, 1),
	Vector3i(1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, 1, 1),
	Vector3i(1, 1, 1),
	Vector3i(1, 1, 0),
]

const EDGES = [
	Vector2i(0, 1),
	Vector2i(1, 2),
	Vector2i(2, 3),
	Vector2i(3, 0),
	Vector2i(4, 5),
	Vector2i(5, 6),
	Vector2i(6, 7),
	Vector2i(7, 4),
	Vector2i(0, 4),
	Vector2i(1, 5),
	Vector2i(2, 6),
	Vector2i(3, 7),
]


@export var ISO:float = 0.1
@export var DATA:Texture3D
@export var FLAT_SHADED:bool = false


@export var GENERATE: bool:
	set(value):
		var time = Time.get_ticks_msec()
		generate()
		var elapsed = (Time.get_ticks_msec()-time)/1000.0
		print("Terrain generated in: " + str(elapsed) + "s")


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func generate():
	var time_send: int = Time.get_ticks_usec()
	var voxel_grid_size := Vector3(DATA.get_width(), DATA.get_height(), DATA.get_depth())
	var voxel_grid := MarchingCubes.VoxelGrid.new(voxel_grid_size)
	voxel_grid.set_data(DATA)
	print("Time to create voxel: " + Utils.parse_time(Time.get_ticks_usec() - time_send))

	# march cubes
	time_send = Time.get_ticks_usec()
	var vertices = PackedVector3Array()
	for z in voxel_grid.size.x - 1:
		for y in voxel_grid.size.y - 1:
			for x in voxel_grid.size.z - 1:
				march_cube(x, y, z, voxel_grid, vertices)
	print("Time to March Cubes: " + Utils.parse_time(Time.get_ticks_usec() - time_send))

	print("Total vertices ", vertices.size())

	# draw
	time_send = Time.get_ticks_usec()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	if FLAT_SHADED:
		surface_tool.set_smooth_group(-1)

	for vert in vertices:
		surface_tool.add_vertex(vert)

	surface_tool.generate_normals()
	surface_tool.index()
	call_deferred("set_mesh", surface_tool.commit())
	print("Time to create surface tool: " + Utils.parse_time(Time.get_ticks_usec() - time_send))

func march_cube(x:int, y:int, z:int, voxel_grid:MarchingCubes.VoxelGrid, vertices:PackedVector3Array):
	for edge_index in get_triangulation(x, y, z, voxel_grid):
		if edge_index < 0: break

		var grid_position := Vector3i(x, y, z)

		# lookup the indices of the corner points making up the current edge
		var point_indices = EDGES[edge_index]
		var p0 = POINTS[point_indices.x]
		var p1 = POINTS[point_indices.y]

		if FLAT_SHADED:
			# find mid point of edge
			vertices.append(Vector3(grid_position) + (p0 + p1) * 0.5)
		else:
			# estimate surface point
			vertices.append(calculate_interpolation( \
								grid_position + p0, \
								grid_position + p1, \
								voxel_grid))


func calculate_interpolation(a:Vector3, b:Vector3, voxel_grid:MarchingCubes.VoxelGrid):
	var val_a = voxel_grid.read(a.x, a.y, a.z)
	var val_b = voxel_grid.read(b.x, b.y, b.z)
	return a.lerp(b, (ISO - val_a) / (val_b - val_a))


func get_triangulation(x:int, y:int, z:int, voxel_grid:MarchingCubes.VoxelGrid):
	var idx = 0b00000000
	for i in range(POINTS.size()):
		idx |= int(voxel_grid.read(
			x + POINTS[i].x,
			y + POINTS[i].y,
			z + POINTS[i].z
		) > ISO) << i
	return MarchingCubes.LUT[idx]
