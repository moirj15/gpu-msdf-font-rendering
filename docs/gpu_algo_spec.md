# Notes from thesis
## Algorithm 1 The general procedure for generating an image (pg 34)

The high level conversion to efficient GPU code is straightforward.
Instead of iterating over each pixel of the output texture serially, we
compute the pixels in parallel by calculating the current output pixel using 
the threadID of the current compute thread.
```c++
RWTexture2D sdf;
void ConstructImage(uint3 threadID)
{
    texCoord = (threadID.xy + 0.5) / float2(sdf.width, sdf.height);
    // Transform texture coordinate to the coordinate system of the vector shape
    float2 coord = TransformCoordinate(texCoord);
    sdf[threadID.xy] = GeneratePixel(coord);
}
```

## Algorithm 2 Finding the closest edge of shape s to a point P (pg 35)
- Have to do some sort of parallel sort
- May have to do multiple compute passes and put into a buffer, maybe a per pixel sort

## Algorithm 3 Pixels of a regular signed distance field
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

## Algorithm 4 Pixels of a pseudo-distance field (pg 35)
```c++
float GeneratePixel(float2 p, Shape shape) 
{
    Edge e = ClosestEdge(p, shape);
    float d = EdgeSignedPseudoDistance(p, e);
    return distanceColor(d);
}
```

## Algorithm 5 Determining the pixel's quadrant
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

## Algorithm 6 Simple edge color assignment assuring that no two adjacent edges of shape S share the same color (pg 40)

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

# Algorithm 7 Pixels of a corner preserving multi-channel distance field (pg 41)
```c++
float3 GeneratePixel(float2 P) 
{
    float dRed = inf;
    float dGreen = inf;
    float dBlue = inf;
    Edge eRed, eGreen, eBlue;

    for (int ci = 0; ci < s.numContours; ci++)
    {
        for (ei = 0; ei < c.numEdges; ei++)
        {
            Edge e = c.edges[ei];
            float d = EdgeSignedDistance(P, e);
            if e.color.r != 0 && CMP(d, dRed) < 0
            {
                dRed = d;
                eRed = e;
            }
            if e.color.g != 0 && CMP(d, dGreen) < 0
            {
                dGreen = d;
                eGreen = e;
            }
            if e.color.b != 0 && CMP(d, dBlue) < 0
            {
                dBlue = d;
                eBlue = e;
            }
        }
    }
    dRed = EdgeSignedPseudoDistance(P, eRed);
    dGreen = EdgeSignedPseudoDistance(P, eGreen);
    dBlue = EdgeSignedPseudoDistance(P, eBlue);
    return distanceColor(float3(dRed, dGreen, dBlue));
}

```

## Math for signed distance (fig 2.41)
Takes a bezier curve of order `n` `B_n` and a point `P`
Note len might actually be absolute value
`sdistance(B_n, P) = sgn(cross(B_n'(t), (B_n(t) - P)))*len(B_n(t) - P)`

## Math for pseudo-signed distance 
For a line segment Equation 2.25 is used

Point `P` and line `(P0, P1)`

`distance(P, (P0, P1)) = len(cross(P, P1 - P0) - cross(P0, P1)) / abs(P1 - P0)`

for curves we must take the distance to the closest edge and calculate for `t`

# GPU Algorithm Design


```c++

struct LinearBezier 
{
    float2 p0;
    float2 p1;
};

struct QuadraticBezier 
{
    float2 p0;
    float2 p1;
    float2 p2;
};

struct CubicBezier 
{
    float2 p0;
    float2 p1;
    float2 p2;
    float2 p3;
};

Buffer<LinearBezier> linearEdges;
Buffer<QuadraticBezier> quadraticEdges;
Buffer<CubicBezier> cubicEdges;

float LinearEdgeSignedDistance(flat2 P, LinearBezier edge);
float QuadraticEdgeSignedDistance(flat2 P, QuadraticBezier edge);
float CubicSignedDistance(flat2 P, CubicBezier edge);

void UpdateDistances(float d, int edge, inout float3 distances, inout int3 edges) 
{
    if e.color.r != 0 && CMP(d, dRed) < 0
    {
        dRed = d;
        eRed = e;
    }
    if e.color.g != 0 && CMP(d, dGreen) < 0
    {
        dGreen = d;
        eGreen = e;
    }
    if e.color.b != 0 && CMP(d, dBlue) < 0
    {
        dBlue = d;
        eBlue = e;
    }
}

float3 GeneratePixelGPU(float2 P) 
{
    float3 linearDistances = {0, 0, 0};
    int3 linearEdges = {-1, -1, -1};
    float3 quadraticDistances = {0, 0, 0};
    int3   quadraticEdges = {-1, -1, -1};
    float3 cubicDistances = {0, 0, 0};
    int3   cubicEdges = {-1, -1, -1};

    for (int i = 0; i < linearEdges.size(); i++) 
    {
        LinearBezier edge = linearEdges[i];
        float d = LinearEdgeSignedDistance(P, edge);
    }
}

```

