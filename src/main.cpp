#include "dx.hpp"
#include "shaderWatcher.hpp"
#include "utils.hpp"

#include <SDL2/SDL.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <msdfgen-ext.h>
#include <msdfgen.h>

constexpr u32 WIDTH  = 1920;
constexpr u32 HEIGHT = 1080;

using namespace msdfgen;
int main(int argc, char **argv)
{
  Bitmap<float, 3> msdf(32, 32);
  if (FreetypeHandle *ft = initializeFreetype())
  {
    if (FontHandle *font = loadFont(ft, "C:\\Windows\\Fonts\\arialbd.ttf"))
    {
      Shape shape;
      if (loadGlyph(shape, font, 'A', FONT_SCALING_EM_NORMALIZED))
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
      destroyFont(font);
    }
    deinitializeFreetype(ft);
  }
  const dx::Window window = dx::CreateWin(WIDTH, HEIGHT, "win");

  dx::RenderContext ctx = dx::InitContext(window);

  f32 clearColor[] = {0.5, 0.5, 0.5, 1.0};

  ShaderWatcher shaderWatcher{ctx.Device()};

  SDL_Event e;
  bool      running = true;

  RenderProgramHandle textRenderProgram =
    shaderWatcher.RegisterShader("shaders/text.hlsl", "shaders/text.hlsl");
  // ComputeProgramHandle msdfGenProgram = shaderWatcher.RegisterShader("shaders/msdf_gen.hlsl");

  ComPtr<ID3D11Texture2D>          msdfTex;
  ComPtr<ID3D11ShaderResourceView> msdfView;
  ComPtr<ID3D11SamplerState>       msdfSampler;

  D3D11_TEXTURE2D_DESC msdfTexDesc = {
    .Width     = static_cast<u32>(msdf.width()),
    .Height    = static_cast<u32>(msdf.height()),
    .MipLevels = 1,
    .ArraySize = 1,
    .Format    = DXGI_FORMAT_R8G8B8A8_UNORM,
    // Multi sampling here
    .SampleDesc =
      {
        .Count   = 1,
        .Quality = 0,
      },
    .Usage          = D3D11_USAGE_DEFAULT,
    .BindFlags      = D3D11_BIND_SHADER_RESOURCE,
    .CPUAccessFlags = 0,
    .MiscFlags      = 0,
  };

  // BitmapRef<float, 3> msdfData = msdf;
  std::vector<u32>         glyphData;
  BitmapConstRef<float, 3> msdfRef = msdf;
  for (u32 y = 0; y < msdfRef.height; y++)
  {
    for (u32 x = 0; x < msdfRef.width; x++)
    {
      u32 rgb = 0xff << 24;
      rgb |= static_cast<u8>(~static_cast<i32>(255.5f - 255.f * clamp(msdfRef(x, y)[2]))) << 16;
      rgb |= static_cast<u8>(~static_cast<i32>(255.5f - 255.f * clamp(msdfRef(x, y)[1]))) << 8;
      rgb |= static_cast<u8>(~static_cast<i32>(255.5f - 255.f * clamp(msdfRef(x, y)[0]))) << 0;
      glyphData.emplace_back(rgb);
    }
  }

  D3D11_SUBRESOURCE_DATA glyphTexData{};
  glyphTexData.pSysMem     = glyphData.data();
  glyphTexData.SysMemPitch = sizeof(u32) * msdf.width();

  dx::ThrowIfFailed(
    ctx.device->CreateTexture2D(&msdfTexDesc, &glyphTexData, msdfTex.GetAddressOf()));

  D3D11_SHADER_RESOURCE_VIEW_DESC quadViewDesc = {
    .Format        = msdfTexDesc.Format,
    .ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D,
    .Texture2D =
      {
        .MostDetailedMip = 0,
        .MipLevels       = 1,
      },
  };

  dx::ThrowIfFailed(
    ctx.device->CreateShaderResourceView(msdfTex.Get(), &quadViewDesc, msdfView.GetAddressOf()));

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

    RenderProgram rp = shaderWatcher.GetRenderProgram(textRenderProgram);

    ctx.context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    // u32 stride = sizeof(ModelVertex);
    // u32 offset = 0;
    // ctx.context->IASetVertexBuffers(0, 1, mVertBuf.GetAddressOf(), &stride, &offset);
    // ctx.context->IASetInputLayout(rp.inputLayout);
    ctx.context->VSSetShader(rp.vertexShader, nullptr, 0);
    // ctx.context->VSSetConstantBuffers(0, 1, mConstantBuf.GetAddressOf());

    ctx.context->RSSetState(ctx.rasterizerState.Get());

    ctx.context->PSSetShader(rp.pixelShader, nullptr, 0);
    ctx.context->PSSetShaderResources(0, 1, msdfView.GetAddressOf());
    ctx.context->PSSetSamplers(0, 1, msdfSampler.GetAddressOf());
    ctx.context->OMSetRenderTargets(
      1,
      ctx.backbufferRTV.GetAddressOf(),
      ctx.depthStencilView.Get());
    // ctx.context->VSSetConstantBuffers(1, 1, mModelConstants[i].GetAddressOf());
    // ctx.context->DrawIndexed(draw.indexCount, draw.startIndex, draw.baseVertex);
    ctx.context->Draw(6, 0);

    dx::ThrowIfFailed(ctx.swapchain->Present(1, 0));
  }

  return 0;
}
