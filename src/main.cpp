#include "dx.hpp"
#include "shaderWatcher.hpp"
#include "utils.hpp"

#include <SDL2/SDL.h>
#include <array>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <msdfgen-ext.h>
#include <msdfgen.h>

constexpr u32 WIDTH  = 1920;
constexpr u32 HEIGHT = 1080;

struct LinearBezier
{
  u32       color;
  glm::vec2 p0;
  glm::vec2 p1;
};

struct QuadraticBezier
{
  u32       color;
  glm::vec2 p0;
  glm::vec2 p1;
  glm::vec2 p2;
};

struct CubicBezier
{
  u32       color;
  glm::vec2 p0;
  glm::vec2 p1;
  glm::vec2 p2;
  glm::vec2 p3;
};

constexpr u32 LINEAR_BEZIER    = 0;
constexpr u32 QUADRATIC_BEZIER = 1;
constexpr u32 CUBIC_BEZIER     = 2;

struct Bezier
{
  u32       color;
  u32       type;
  glm::vec2 p0;
  glm::vec2 p1;
  glm::vec2 p2;
  glm::vec2 p3;
};

struct GlyphBounds
{
  f32 l_bound{};
  f32 b_bound{};
  f32 r_bound{};
  f32 t_bound{};
};

struct Glyph
{
  GlyphBounds         bounds;
  std::vector<Bezier> edges;
};

using namespace msdfgen;
Glyph CreateGlyph(char c, FontHandle *font)
{
  Glyph glyph{};
  // std::vector<Bezier> segments;
  Bitmap<float, 3> msdf(32, 32);
  // GlyphBounds         bounds;
  Shape shape;
  if (loadGlyph(shape, font, c, FONT_SCALING_EM_NORMALIZED))
  {
    shape.normalize();
    //                      max. angle
    edgeColoringSimple(shape, 3.0);
    //          output width, height
    //                            scale, translation (in em's)
    SDFTransformation t(Projection(32, Vector2(0.125, 0.125)), Range(0.125));
    generateMSDF(msdf, shape, t);
    savePng(msdf, "output.png");
  }
  // BLACK = 0,
  // RED = 1,
  // GREEN = 2,
  // YELLOW = 3,
  // BLUE = 4,
  // MAGENTA = 5,
  // CYAN = 6,
  // WHITE = 7

  glm::vec3 colors[] = {
    {0, 0, 0},
    {1, 0, 0},
    {0, 1, 0},
    {1, 1, 0},
    {0, 0, 1},
    {0, 1, 1},
    {1, 1, 1},
  };
  // shape.orientContours();
  double l{}, b{}, r{}, t{};
  shape.bound(l, b, r, t);
  double ur            = 4 * 1.0 / 32.0;
  glyph.bounds.l_bound = (((l + 0.125) * 32.0 + 0.5) / 512.0);
  glyph.bounds.b_bound = (((b + 0.125) * 32.0 + 0.5) / 512.0);
  glyph.bounds.r_bound = (((r + 0.125) * 32.0 + 0.5) / 512.0);
  glyph.bounds.t_bound = (((t + 0.125) * 32.0 + 0.5) / 512.0);

  glm::vec3 color{};
  for (auto &c : shape.contours)
  {
    if (c.edges.size() == 1)
      color = {1.0, 1.0, 1.0};
    else
      color = {1.0, 0.0, 1.0};
    for (auto &e : c.edges)
    {
      if (e->type() == msdfgen::LinearSegment::EDGE_TYPE)
      {
        auto *edge = static_cast<msdfgen::LinearSegment *>(&(*e));
        glyph.edges.push_back(Bezier{
          // glm::packUnorm4x8(glm::vec4{color, 1.0}),
          glm::packUnorm4x8(glm::vec4{colors[edge->color], 1.0}),
          LINEAR_BEZIER,
          glm::vec2{edge->p[0].x, edge->p[0].y},
          glm::vec2{edge->p[1].x, edge->p[1].y},
        });
      }
      else if (e->type() == msdfgen::QuadraticSegment::EDGE_TYPE)
      {
        e->reverse();
        auto *edge = static_cast<msdfgen::QuadraticSegment *>(&(*e));
        glyph.edges.push_back(Bezier{
          // glm::packUnorm4x8(glm::vec4{color, 1.0}),
          glm::packUnorm4x8(glm::vec4{colors[edge->color], 1.0}),
          QUADRATIC_BEZIER,
          glm::vec2{edge->p[0].x, edge->p[0].y},
          glm::vec2{edge->p[1].x, edge->p[1].y},
          glm::vec2{edge->p[2].x, edge->p[2].y},
        });
      }
      else if (e->type() == msdfgen::CubicSegment::EDGE_TYPE)
      {
        auto *edge = static_cast<msdfgen::CubicSegment *>(&(*e));
        glyph.edges.push_back(Bezier{
          // glm::packUnorm4x8(glm::vec4{color, 1.0}),
          glm::packUnorm4x8(glm::vec4{colors[edge->color], 1.0}),
          CUBIC_BEZIER,
          glm::vec2{edge->p[0].x, edge->p[0].y},
          glm::vec2{edge->p[1].x, edge->p[1].y},
          glm::vec2{edge->p[2].x, edge->p[2].y},
          glm::vec2{edge->p[3].x, edge->p[3].y},
        });
      }
      if (color == glm::vec3{1.0, 1.0, 0.0})
        color = {0, 1, 1};
      else
        color = {1, 1, 0};
    }
  }

  return glyph;
}

int main(int argc, char **argv)
{
  FreetypeHandle *ft = initializeFreetype();
  if (!ft)
  {
    printf("Failed to initialize freetype\n");
    return 0;
  }
  FontHandle *font = loadFont(ft, "C:\\Windows\\Fonts\\arialbd.ttf");
  if (!font)
  {
    printf("Failed to load font\n");
    return 0;
  }
  // std::vector<LinearBezier>    linearSegments;
  // std::vector<QuadraticBezier> quadraticSegments;
  // std::vector<CubicBezier>     cubicSegments;
  // std::sort(linearSegments.begin(), linearSegments.end(), [](auto &a, auto &b) {
  //   return glm::all(glm::lessThan(a.p0, b.p0));
  // });
  std::vector<Glyph> glyphs;
  for (char c = 'a'; c <= 'z'; c++)
  {
    glyphs.push_back(CreateGlyph(c, font));
  }
  auto             glyph1 = CreateGlyph('c', font);
  auto             glyph2 = CreateGlyph('a', font);
  const dx::Window window = dx::CreateWin(WIDTH, HEIGHT, "msdf gpu gen");

  dx::RenderContext ctx = dx::InitContext(window);

  auto textCB       = dx::CreateConstantBuffer<GlyphBounds>(ctx.Device(), &glyph1.bounds);
  f32  clearColor[] = {0.5, 0.5, 0.5, 1.0};

  ShaderWatcher shaderWatcher{ctx.Device()};

  SDL_Event e;
  bool      running = true;

  RenderProgramHandle textRenderProgram =
    shaderWatcher.RegisterShader("shaders/text.hlsl", "shaders/text.hlsl");

  auto msdfGenCS = shaderWatcher.RegisterShader("shaders/msdf_gen.hlsl");
  // ComputeProgramHandle msdfGenProgram = shaderWatcher.RegisterShader("shaders/msdf_gen.hlsl");

  ComPtr<ID3D11Texture2D>          msdfTex;
  ComPtr<ID3D11ShaderResourceView> msdfView;
  ComPtr<ID3D11SamplerState>       msdfSampler;

  // D3D11_TEXTURE2D_DESC msdfTexDesc = {
  //   .Width     = static_cast<u32>(msdf.width()),
  //   .Height    = static_cast<u32>(msdf.height()),
  //   .MipLevels = 1,
  //   .ArraySize = 1,
  //   .Format    = DXGI_FORMAT_R8G8B8A8_UNORM,
  //   // Multi sampling here
  //   .SampleDesc =
  //     {
  //       .Count   = 1,
  //       .Quality = 0,
  //     },
  //   .Usage          = D3D11_USAGE_DEFAULT,
  //   .BindFlags      = D3D11_BIND_SHADER_RESOURCE,
  //   .CPUAccessFlags = 0,
  //   .MiscFlags      = 0,
  // };

  constexpr u32 ATLAS_WIDTH  = 512;
  constexpr u32 ATLAS_HEIGHT = 512;

  D3D11_TEXTURE2D_DESC gpuMsdfTexDesc = {
    .Width     = ATLAS_WIDTH,
    .Height    = ATLAS_HEIGHT,
    .MipLevels = 1,
    .ArraySize = 1,
    .Format    = DXGI_FORMAT_R32G32B32A32_FLOAT,
    //.Format = DXGI_FORMAT_R8G8B8A8_UNORM,
    // Multi sampling here
    .SampleDesc =
      {
        .Count   = 1,
        .Quality = 0,
      },
    .Usage          = D3D11_USAGE_DEFAULT,
    .BindFlags      = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS,
    .CPUAccessFlags = 0,
    .MiscFlags      = 0,
  };

  ComPtr<ID3D11Texture2D> gpuMsdfTex;
  dx::ThrowIfFailed(
    ctx.device->CreateTexture2D(&gpuMsdfTexDesc, nullptr, gpuMsdfTex.GetAddressOf()));

  ComPtr<ID3D11UnorderedAccessView> msdfCSView;
  dx::ThrowIfFailed(
    ctx.device->CreateUnorderedAccessView(gpuMsdfTex.Get(), nullptr, msdfCSView.GetAddressOf()));

  ComPtr<ID3D11ShaderResourceView> gpuMsdfView;
  dx::ThrowIfFailed(
    ctx.device->CreateShaderResourceView(gpuMsdfTex.Get(), nullptr, gpuMsdfView.GetAddressOf()));

  // auto linearBuf = dx::CreateVertexBuffer<LinearBezier>(
  //   ctx.device.Get(),
  //   linearSegments.size(),
  //   {linearSegments.begin(), linearSegments.end()});

  // auto quadraticBuf = dx::CreateVertexBuffer<QuadraticBezier>(
  //   ctx.device.Get(),
  //   quadraticSegments.size(),
  //   {quadraticSegments.begin(), quadraticSegments.end()});

  // auto cubicBuf = dx::CreateVertexBuffer<CubicBezier>(
  //   ctx.device.Get(),
  //   cubicSegments.size(),
  //   {cubicSegments.begin(), cubicSegments.end()});
  struct GlyphRange
  {
    u32 edgeStart;
    u32 edgeCount;
  };

  std::vector<Bezier>     combinedGlyphEdges;
  std::vector<GlyphRange> glyphRanges;
  // combinedGlyphEdges.append_range(glyph1.edges);
  // combinedGlyphEdges.append_range(glyph2.edges);
  u32 offset = 0;
  for (const auto &g : glyphs)
  {
    combinedGlyphEdges.append_range(g.edges);
    glyphRanges.push_back({offset, (u32)g.edges.size()});
    offset += g.edges.size();
  }

  auto segmentBuf = dx::CreateVertexBuffer<Bezier>(
    ctx.device.Get(),
    combinedGlyphEdges.size(),
    {combinedGlyphEdges.begin(), combinedGlyphEdges.end()});

  // std::array<GlyphRange, 2> glyphStartIndices = {
  //   GlyphRange{0, (u32)glyph1.edges.size()},
  //   GlyphRange{(u32)glyph1.edges.size(), (u32)glyph2.edges.size()},
  // };

  auto glyphStartIndicesBuf = dx::CreateVertexBuffer<GlyphRange>(
    ctx.device.Get(),
    glyphRanges.size(),
    {glyphRanges.begin(), glyphRanges.end()});

  // BitmapRef<float, 3> msdfData = msdf;
  std::vector<u32> glyphData;
  // BitmapConstRef<float, 3> msdfRef = msdf;
  // for (u32 y = 0; y < msdfRef.height; y++)
  //{
  //   for (u32 x = 0; x < msdfRef.width; x++)
  //   {
  //     u32 rgb = 0xff << 24;
  //     rgb |= static_cast<u8>(~static_cast<i32>(255.5f - 255.f * clamp(msdfRef(x, y)[2]))) << 16;
  //     rgb |= static_cast<u8>(~static_cast<i32>(255.5f - 255.f * clamp(msdfRef(x, y)[1]))) << 8;
  //     rgb |= static_cast<u8>(~static_cast<i32>(255.5f - 255.f * clamp(msdfRef(x, y)[0]))) << 0;
  //     glyphData.emplace_back(rgb);
  //   }
  // }

  // D3D11_SUBRESOURCE_DATA glyphTexData{};
  // glyphTexData.pSysMem     = glyphData.data();
  // glyphTexData.SysMemPitch = sizeof(u32) * msdf.width();

  // dx::ThrowIfFailed(
  //   ctx.device->CreateTexture2D(&msdfTexDesc, &glyphTexData, msdfTex.GetAddressOf()));

  // D3D11_SHADER_RESOURCE_VIEW_DESC quadViewDesc = {
  //   .Format        = msdfTexDesc.Format,
  //   .ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D,
  //   .Texture2D =
  //     {
  //       .MostDetailedMip = 0,
  //       .MipLevels       = 1,
  //     },
  // };

  // dx::ThrowIfFailed(
  //   ctx.device->CreateShaderResourceView(msdfTex.Get(), &quadViewDesc, msdfView.GetAddressOf()));

  CD3D11_SAMPLER_DESC samplerDesc{CD3D11_DEFAULT{}};
  dx::ThrowIfFailed(ctx.device->CreateSamplerState(&samplerDesc, msdfSampler.GetAddressOf()));

  while (running)
  {
    while (SDL_PollEvent(&e) > 0)
    {
      if (e.type == SDL_QUIT)
      {
        running = false;
      }
    }
    SDL_PumpEvents();
    ctx.context->ClearRenderTargetView(ctx.backbufferRTV.Get(), clearColor);
    ctx.context->ClearDepthStencilView(ctx.depthStencilView.Get(), D3D11_CLEAR_DEPTH, 1.0, 0);

    {
      ctx.DeviceContext()->CSSetShader(shaderWatcher.GetComputeProgram(msdfGenCS), nullptr, 0);
      ctx.DeviceContext()->CSSetUnorderedAccessViews(0, 1, msdfCSView.GetAddressOf(), nullptr);
      // std::array resources = {
      //   linearBuf.view.Get(),
      //   quadraticBuf.view.Get(),
      //   cubicBuf.view.Get(),
      // };
      // ctx.DeviceContext()->CSSetShaderResources(0, 3, resources.data());
      std::array srvs = {segmentBuf.view.Get(), glyphStartIndicesBuf.view.Get()};
      ctx.DeviceContext()->CSSetShaderResources(0, 2, srvs.data());
      ctx.DeviceContext()->Dispatch(4, 4, glyphs.size());
      ID3D11UnorderedAccessView *v[] = {nullptr, nullptr};
      ctx.DeviceContext()->CSSetUnorderedAccessViews(0, 2, v, nullptr);
    }

    RenderProgram rp = shaderWatcher.GetRenderProgram(textRenderProgram);

    // ctx.context->ClearState();
    ctx.context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    // u32 stride = sizeof(ModelVertex);
    // u32 offset = 0;
    // ctx.context->IASetVertexBuffers(0, 1, mVertBuf.GetAddressOf(), &stride, &offset);
    // ctx.context->IASetInputLayout(rp.inputLayout);
    ctx.context->VSSetShader(rp.vertexShader, nullptr, 0);
    // ctx.context->VSSetConstantBuffers(0, 1, mConstantBuf.GetAddressOf());

    ctx.context->RSSetState(ctx.rasterizerState.Get());

    ctx.context->PSSetShader(rp.pixelShader, nullptr, 0);
#if 0
    ctx.context->PSSetShaderResources(0, 1, msdfView.GetAddressOf());
#else
    ctx.context->PSSetShaderResources(0, 1, gpuMsdfView.GetAddressOf());
#endif
    ctx.context->PSSetSamplers(0, 1, msdfSampler.GetAddressOf());
    ctx.context->PSSetConstantBuffers(0, 1, textCB.GetAddressOf());
    ctx.context->OMSetRenderTargets(
      1,
      ctx.backbufferRTV.GetAddressOf(),
      ctx.depthStencilView.Get());
    // ctx.context->VSSetConstantBuffers(1, 1, mModelConstants[i].GetAddressOf());
    // ctx.context->DrawIndexed(draw.indexCount, draw.startIndex, draw.baseVertex);
    ctx.context->Draw(6, 0);
    ID3D11ShaderResourceView *srv = nullptr;
    ctx.context->PSSetShaderResources(0, 1, &srv);

    ctx.swapchain->Present(1, 0);
  }

  destroyFont(font);
  deinitializeFreetype(ft);

  return 0;
}
