
# Algorithm 1 The general procedure for generating an image (pg 34)

The high level conversion to efficient GPU code is straightforward.
Instead of iterating over each pixel of the output texture serially, we
compute the pixels in parallel by calculating the current output pixel using 
the threadID of the current compute thread.
```c++
RWTexture2D sdf;
void ConstructImage(uint3 threadID)
{
    texCoord = (threadID.xy + 0.5) / float2(sdf.width, sdf.height);
    float2 coord = TransformCoordinate(texCoord);
    sdf[threadID.xy] = GeneratePixel(coord);
}
```

# Algorithm 2 Finding the closest edge of shape s to a point P (pg 35)
- Have to do some sort of parallel sort
- May have to do multiple compute passes and put into a buffer, maybe a per pixel sort

# Algorithm 3 Pixels of a regular signed distance field
```c++

struct Edge 
{
    float2 start;
    float2 end;
};

struct Shape 
{
    uint numEdges;
    Edge edges[];
};

float GeneratePixel(float2 p, Shape shape) 
{
    Edge e = ClosestEdge(p, shape);
    float d = EdgeSignedDistance(p, e);
    return distanceColor(d);
}
```

# Algorithm 4 Pixels of a pseudo-distance field (pg 35)
```c++
float GeneratePixel(float2 p, Shape shape) 
{
    Edge e = ClosestEdge(p, shape);
    float d = EdgeSignedPseudoDistance(p, e);
    return distanceColor(d);
}
```

# Algorithm 5 Determining the pixel's quadrant
edge portion `t`, range `[0, 1]`
point `P`
endpoint `A`
endpoint `B`
neighboring edges `n_A` and `n_B`, at the respective endpoints
signed distance `d`

```c++

enum Quadrant {
    InnerCore,
    InnerBorder,
    OuterOpposite,
    OuterBorder,
}

Quadrant FindQuadrant(float2 P, float signedDistance, float closestPortion) {
    bool core;
    if (closestPortion < 0.5) 
    {
        core = 
    }
    else
    {

    }
}

```

# Algorithm 6 Simple edge color assignment assuring that no two adjacent edges of shape S share the same color

```c++

struct Edge 
{
    float3 color;
}

struct Contour 
{
    uint numEdges;
    Edge edges[]
};

struct Shape 
{
    uint numContours
    Contour contours[];
};

void EdgeColoring(Shape s) 
{
    float3 color;
    for (int ci = 0; ci < s.numContours; ci++)
    {
        Contour c = s.contours[ci];
        if (c.numEdges == 1) 
        {
            color = float3(1, 1, 1);
        }
        else 
        {
            color = float3(1, 0, 1);
        }
        for (ei = 0; ei < c.numEdges; ei++)
        {
            Edge e = c.edges[ei];
            e.color = color;
            if (color == float3(1, 1, 0))
            {
                color = float3(0, 1, 1);
            } 
            else 
            {
                color = float3(1, 1, 0);
            }
        }
    }

    return color;
}
```