#include "dx.hpp"
#include "shaderWatcher.hpp"
#include "utils.hpp"

#include <SDL2/SDL.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

constexpr u32 WIDTH  = 1920;
constexpr u32 HEIGHT = 1080;

int main(int argc, char **argv)
{
  const dx::Window window = dx::CreateWin(WIDTH, HEIGHT, "win");

  dx::RenderContext ctx = dx::InitContext(window);

  f32 clearColor[] = {0.5, 0.5, 0.5, 1.0};

  ShaderWatcher shaderWatcher{ctx.Device()};

  glm::dmat4 projection = glm::infinitePerspective(90.0, (double)WIDTH / (double)HEIGHT, 0.001);

  SDL_Event e;
  bool      running       = true;
  bool      firstBtnPress = false;
  bool      btnReleased   = true;

  i32 lastMouseX{}, lastMouseY{};
  i32 currMouseX{}, currMouseY{};

  auto ToNDC = [](i32 x, i32 y) -> glm::vec2 {
    return {
      ((f32)x / WIDTH) * 2.0 - 1.0,
      -(((f32)y / HEIGHT) * 2.0 - 1.0),
    };
  };

  u32 currTime{}, lastTime{};
  while (running)
  {
    lastTime        = currTime;
    currTime        = SDL_GetPerformanceCounter();
    const f64 delta = (((f64)currTime - (f64)lastTime) / SDL_GetPerformanceFrequency());
    while (SDL_PollEvent(&e) > 0)
    {
      if (e.type == SDL_QUIT)
      {
        running = false;
      }
    }
    SDL_PumpEvents();
    i32       x{}, y{};
    const u32 btn = SDL_GetMouseState(&x, &y);
    if ((btn & SDL_BUTTON_LMASK) != 0)
    {
      if (firstBtnPress)
      {
        firstBtnPress = false;
        lastMouseX    = x;
        lastMouseY    = y;
        currMouseX    = x;
        currMouseY    = y;
      }
      else
      {
        lastMouseX = currMouseX;
        lastMouseY = currMouseY;
        currMouseX = x;
        currMouseY = y;
      }
      btnReleased = false;
      currMouseX  = x;
      currMouseY  = y;
    }
    else
    {
      firstBtnPress = true;
      lastMouseX    = x;
      lastMouseY    = y;
      currMouseX    = x;
      currMouseY    = y;
    }

    ctx.context->ClearRenderTargetView(ctx.backbufferRTV.Get(), clearColor);
    ctx.context->ClearDepthStencilView(ctx.depthStencilView.Get(), D3D11_CLEAR_DEPTH, 1.0, 0);
    ctx.swapchain->Present(1, 0);
  }
  return 0;
}
