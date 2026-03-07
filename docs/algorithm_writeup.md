

- Thesis goes over a number of methods for generating distance fields
- We'll be focusing on the author's algorithms for generating multi signed distance fields
- The algrithm is in two stages
  - Edge coloring
  - Distance calculation
- Edge coloring can be done serially on the CPU or GPU
- Distance calculations can be done in parallel on the GPU with some modification
  - Since we lack virtual functions in HLSL and performance is a major concern, the edges will have to be split into several buffers
  - To reduce on memory usage we'll pack the edge color into a 32-bit integer, unpacking as necessary
  - We'll take advantage of HLSL's native vector types to store our unpacked colors and distances
- There's two approaches that can be taken to implement on the GPU
  - First approach (first one I came up with), where we take advantage of the fact that the original algorithm doesn't depend on the ordering of edges. So we process each type of bezier curve before the next
  - Second approach is to split the bezier processing into their own dispatches (one for linear, quadratic, and cubic) and have a final dispatch pass that determines the final distance output

# sheet approach
- This is a straightforward extension of the previously described method
- We modify the output stage of the previous algorithm so it writes into the font sheet directly, instead of a single texture.
- This will require the bounds within the sheet to be calculated
- This will have to be done serially