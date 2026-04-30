struct VSOut
{
  float4 position : SV_Position;
  float2 texCoord : TEXCOORD;
  float2 boundOffset : POSITION;
};

cbuffer vsconstants : register(b0)
{
  float2 position;
  float2 scale;
  float2 uvStart;
  float2 uvSize;
}

VSOut VSMain(uint vertexID : SV_VertexID)
{
  //float2 pos[] =
  //{
  //  float2(-1.0, 1.0),
  //  float2(-1.0, -1.0),
  //  float2(1.0, 1.0),
  //  float2(1.0, 1.0),
  //  float2(-1.0, -1.0),
  //  float2(1.0, -1.0),
  //};
  float2 pos[] =
  {
    float2(position.x, position.y + scale.y),
    float2(position.x, position.y),
    float2(position.x + scale.x, position.y + scale.y),
    float2(position.x + scale.x, position.y + scale.y),
    float2(position.x, position.y),
    float2(position.x + scale.x, position.y),
  };
  //float2 texCoord[] =
  //{
  //  float2(0, 1),
  //  float2(0, 0),
  //  float2(1, 1),
  //  float2(1, 1),
  //  float2(0, 0),
  //  float2(1, 0),
  //};
  float2 texCoord[] =
  {
    float2(uvStart.x, uvStart.y + uvSize.y),
    float2(uvStart.x, uvStart.y),
    float2(uvStart.x + uvSize.x, uvStart.y + uvSize.y),
    float2(uvStart.x + uvSize.x, uvStart.y + uvSize.y),
    float2(uvStart.x, uvStart.y),
    float2(uvStart.x + uvSize.x, uvStart.y),
  };
  VSOut ret = (VSOut) 0;
  //ret.position = float4((pos[vertexID] + position) * uvSize, 0, 1);
  ret.position = float4(texCoord[vertexID].x - 0.5, texCoord[vertexID].y, 0, 1);
  ret.texCoord = texCoord[vertexID];// * (32.0 / 512.0);
  ret.boundOffset = uvStart;
  return ret;
}


Texture2D msdf : register(t0);
SamplerState samp : register(s0);
cbuffer constants : register(b0)
{
  float l_bound;
  float b_bound;
  float r_bound;
  float t_bound;
}

//uniform vec4 bgColor;
//uniform vec4 fgColor;
static const float4 bgColor = float4(0.0, 0.0, 0.0, 0.0);
static const float4 fgColor = float4(1.0, 1.0, 1.0, 1.0);

//cbuffer constants : register(b0)
//{
//  float pxRange; // set to distance field's pixel range
//};
//static const float pxRange = 1920.0 / 32.0;
//static const float2 pxRange = { 1920.0 / 32.0, 1080.0 / 32.0 };
static const float pxRange = 4.0;

float2 sqr(float2 x)
{
  return x * x;
}

float screenPxRange(float2 texCoord)
{
  uint2 texSize = uint2(32, 32);
  uint mipCount = 0;
  //msdf.GetDimensions(0, texSize.x, texSize.y, mipCount);
  //float2 unitRange = float2(pxRange, pxRange) / float2(texSize);
  float2 unitRange = pxRange.xx / float2(texSize);
    // If inversesqrt is not available, use vec2(1.0)/sqrt
  float2 screenTexSize = rsqrt(sqr(ddx_fine(texCoord)) + rsqrt(ddy_fine(texCoord)));
    // Can also be approximated as screenTexSize = vec2(1.0)/fwidth(texCoord);
  return max(0.5 * dot(unitRange, screenTexSize), 1.0);
}

float median(float r, float g, float b)
{
  return max(min(r, g), min(max(r, g), b));
}

float4 PSMain(VSOut vsOut) : SV_Target
{
  float2 min = float2(5.0 / 32.0, 5.0 / 32.0);
  float2 max = float2(27.0 / 32.0, 27.0 / 32.0);

  if (vsOut.texCoord.x < l_bound + vsOut.boundOffset || vsOut.texCoord.y < b_bound || vsOut.texCoord.x > r_bound || vsOut.texCoord.y > t_bound)
    return fgColor;
  float3 msd = msdf.Sample(samp, vsOut.texCoord).rgb;
  float sd = median(msd.r, msd.g, msd.b);
  float screenPxDistance = screenPxRange(vsOut.texCoord) * (sd - 0.5);
  float opacity = clamp(screenPxDistance + 0.5, 0.0, 1.0);
  return lerp(bgColor, fgColor, opacity);
}