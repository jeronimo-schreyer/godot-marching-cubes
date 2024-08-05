# Cubes on the March
Godot 4 CPU &amp; GPU Marching Cubes Implementation

This project is an implementation of the Marching Cubes algorithm using both CPU and GPU (compute shaders). It aims to demonstrate the performance differences and techniques between the two approaches in generating 3D meshes from volumetric data.

## Project Structure

The project contains two main scenes:

- **res://marching_cubes.tscn**: Implementation of the Marching Cubes algorithm using the CPU.
- **res://computed_marching_cubes.tscn**: Implementation of the Marching Cubes algorithm using the GPU with compute shaders.

## Data Sources

Two images are provided as volumetric data sources (Texture3D) for mesh generation:

- **res://data/64x64x64.png**
- **res://data/128x128x128.png**

Each image is a spritesheet containing vertical slices of [Suzanne](https://es.m.wikipedia.org/wiki/Archivo:Blender_suzanne.jpg) that will be processed by the algorithm to generate the mesh.

## Usage

To use the scenes and generate a mesh, follow these steps:

1. Open either the `marching_cubes.tscn` or `computed_marching_cubes.tscn` scene in Godot.
2. Assign the image you want to process (either `64x64x64.png` or `128x128x128.png`) to the `DATA` param.
3. Click on the "Generate" checkbox to start the mesh generation process.

![Captura de pantalla 2024-08-05 160152](https://github.com/user-attachments/assets/0ae9436d-be65-4d76-9cc1-a776d276c3e1)

## Requirements

- Tested on Godot Engine 4.3
- A compatible GPU for running the compute shader implementation

## Notes

- The CPU implementation is suitable for understanding the basic workings of the Marching Cubes algorithm.
- The GPU implementation showcases how compute shaders can be utilized for improved performance in processing volumetric data.

## References

- [Sebastian Lague's YouTube Video on Marching Cubes](https://www.youtube.com/watch?v=M3iI2l0ltbE)
- [SebLague/Godot-Marching-Cubes on GitHub](https://github.com/SebLague/Godot-Marching-Cubes)
- [jbernardic/Godot-Smooth-Voxels on GitHub](https://github.com/jbernardic/Godot-Smooth-Voxels)

## License

This project is licensed under the GNU General Public License v3.0. See the `LICENSE` file for more details.
