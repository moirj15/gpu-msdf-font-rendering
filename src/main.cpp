#include "dx.hpp"
#include "shaderWatcher.hpp"
#include "utils.hpp"

#include <SDL2/SDL.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

constexpr u32 WIDTH = 1920;
constexpr u32 HEIGHT = 1080;

int main(int argc, char **argv) {
  const dx::Window window = dx::CreateWin(WIDTH, HEIGHT, "win");

  dx::RenderContext ctx = dx::InitContext(window);

  f32 clearColor[] = {0.5, 0.5, 0.5, 1.0};

  ShaderWatcher shaderWatcher{ctx.Device()};


  SDL_Event e;
  bool running = true;

  while (running) {
    while (SDL_PollEvent(&e) > 0) {
      if (e.type == SDL_QUIT) {
        running = false;
      }
    }
    SDL_PumpEvents();
    ctx.context->ClearRenderTargetView(ctx.backbufferRTV.Get(), clearColor);
    ctx.context->ClearDepthStencilView(ctx.depthStencilView.Get(), D3D11_CLEAR_DEPTH, 1.0, 0);
    dx::ThrowIfFailed(ctx.swapchain->Present(1, 0));
  }

  return 0;
}
