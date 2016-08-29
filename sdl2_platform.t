local C = terralib.includecstring([[
#include <stdio.h>
#include "./thirdparty/include/glew.h"
#include <SDL2/SDL.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreturn-type"

#include "./thirdparty/nanovg/src/nanovg.h"
#define NANOVG_GL3_IMPLEMENTATION
#include "./thirdparty/nanovg/src/nanovg_gl.h"

#pragma clang diagnostic pop
]], {"-O2"})
-- #include "imgui_impl_sdl_gl3.h"

function generate_platform(dynamic_runtime)
  require "platform"

  local struct PlatformState
  {
    window : &C.SDL_Window
    vg : &C.NVGcontext
    reload_requested : bool
    platform_info : &PlatformInfo

    update_time : uint64
    frame_time : uint64
    last_counter : uint64
    last_start_time : uint64
    target_seconds_per_frame : float

    running : bool
  }

  local platform = {}

  terra platform.init() : &PlatformState
    var platform_state = [&PlatformState](C.malloc(sizeof(PlatformState)))
    
    -- Init SDL2
    if (C.SDL_Init(C.SDL_INIT_VIDEO) == -1) then
      C.printf("Error initializing sdl")
      return nil
    end

    C.SDL_GL_SetAttribute(C.SDL_GL_CONTEXT_FLAGS,
                          C.SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG)
    C.SDL_GL_SetAttribute(C.SDL_GL_CONTEXT_MAJOR_VERSION, 3)
    C.SDL_GL_SetAttribute(C.SDL_GL_CONTEXT_MINOR_VERSION, 2)
    C.SDL_GL_SetAttribute(C.SDL_GL_CONTEXT_PROFILE_MASK,
                          C.SDL_GL_CONTEXT_PROFILE_CORE)

    C.SDL_GL_SetAttribute(C.SDL_GL_DOUBLEBUFFER, 1);
    C.SDL_GL_SetAttribute(C.SDL_GL_DEPTH_SIZE, 24);
    C.SDL_GL_SetAttribute(C.SDL_GL_STENCIL_SIZE, 8);

    platform_state.window = C.SDL_CreateWindow("Terra Game",
                                               C.SDL_WINDOWPOS_CENTERED_MASK,
                                               C.SDL_WINDOWPOS_CENTERED_MASK,
                                               1024,
                                               768,
                                               C.SDL_WINDOW_OPENGL or
                                               C.SDL_WINDOW_RESIZABLE or
                                               C.SDL_WINDOW_ALLOW_HIGHDPI);

    if platform_state.window == nil then
      C.printf("Error creating window: %s\n", C.SDL_GetError())
    end

    var context = C.SDL_GL_CreateContext(platform_state.window);
    if context == nil then
        C.printf("Error creating opengl context: %s\n", C.SDL_GetError())
    end

    C.glewExperimental = C.GL_TRUE
    C.glewInit()
    C.glGetError()

    -- Use Vsync
    if C.SDL_GL_SetSwapInterval(1) < 0 then
        C.printf("Unable to set VSync! SDL Error: %s\n", C.SDL_GetError())
    end

    var display_mode : C.SDL_DisplayMode
    C.SDL_GetDisplayMode(0, 0, &display_mode);
    C.printf("Display Mode update hz: %i\n", display_mode.refresh_rate)

    var game_update_hz = [float](display_mode.refresh_rate)
    platform_state.target_seconds_per_frame = 1.0 / game_update_hz;

    -- // Setup imgui
    -- ImGui_ImplSdlGL3_Init(window);

    platform_state.vg = C.nvgCreateGL3(C.NVG_ANTIALIAS or C.NVG_STENCIL_STROKES or C.NVG_DEBUG)
    if platform_state.vg == nil then
      C.printf("Error initializing nanovg")
    end

    platform_state.platform_info = [&PlatformInfo](C.calloc(sizeof(PlatformInfo), 1))

    platform_state.platform_info.persistent_memory = [&uint8](C.malloc(1024))
    platform_state.platform_info.persistent_memory_capacity = 1024

    platform_state.platform_info.temp_memory = [&uint8](C.malloc(1024))
    platform_state.platform_info.temp_memory_capacity = 1024

    platform_state.platform_info.dt = 0
    platform_state.platform_info.ticks = 0
    
    platform_state.platform_info.vg = platform_state.vg

    platform_state.update_time = 0;
    platform_state.frame_time = 0;

    platform_state.last_counter = C.SDL_GetPerformanceCounter();
    platform_state.last_start_time = C.SDL_GetTicks();

    platform_state.running = true
    
    return platform_state
  end

  terra platform.shouldKeepRunning(platform_state : &PlatformState) : bool
    return platform_state.running
  end

  terra platform.mainLoop(platform_state : &PlatformState,
                          updateAndRender : {&PlatformInfo} -> {}) : &PlatformState

    var start_time = C.SDL_GetTicks()
    platform_state.frame_time = start_time - platform_state.last_start_time
    platform_state.last_start_time = start_time

    var event : C.SDL_Event
    while C.SDL_PollEvent(&event) > 0 do
      -- ImGui_ImplSdlGL3_ProcessEvent(&event);
      if event.type == C.SDL_QUIT then
        platform_state.running = false
        break
      end
    end
    
    -- @TODO; Not exactly sure what I want to pass here.
    -- start_time is the time the frame started at.
    platform_state.platform_info.ticks = start_time

    --     // @TODO: this is the last frame's length, not this one.
    platform_state.platform_info.dt = [float](platform_state.frame_time * 0.001)

    var w : int
    var h : int
    var display_w : int
    var display_h : int
    C.SDL_GetWindowSize(platform_state.window, &w, &h);
    C.SDL_GL_GetDrawableSize(platform_state.window, &display_w, &display_h);

    var ratio = [float](display_w) / [float](display_h)

    platform_state.platform_info.window_width = w
    platform_state.platform_info.window_height = h
    platform_state.platform_info.display_width = display_w
    platform_state.platform_info.display_height = display_h

    C.glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    C.glClear(C.GL_COLOR_BUFFER_BIT or C.GL_DEPTH_BUFFER_BIT or C.GL_STENCIL_BUFFER_BIT);

    --     ImGui_ImplSdlGL3_NewFrame(window);

    C.nvgBeginFrame(platform_state.vg, w, h, display_w/w);

    updateAndRender(platform_state.platform_info)

    -- C.nvgBeginPath(platform_state.vg);
    -- C.nvgRect(platform_state.vg, 10, 10, 1004, 748);
    -- C.nvgStrokeColor(platform_state.vg, C.nvgRGBf(1,0,0));
    -- C.nvgStroke(platform_state.vg);

    C.nvgEndFrame(platform_state.vg)

    --     glViewport(0, 0, (int)ImGui::GetIO().DisplaySize.x, (int)ImGui::GetIO().DisplaySize.y);
    --     ImGui::Render();

    platform_state.update_time = C.SDL_GetTicks() - start_time;
    var time_till_vsync = platform_state.target_seconds_per_frame * 1000.0 - (C.SDL_GetTicks() - start_time)
    if time_till_vsync > 4.0 then
      C.SDL_Delay([uint32](time_till_vsync - 3))
    end

    C.SDL_GL_SwapWindow(platform_state.window)

    var end_counter = C.SDL_GetPerformanceCounter();
    platform_state.last_counter = end_counter;
  end

  terra platform.cleanup(platform_state : &PlatformState)
    -- ImGui_ImplSdlGL3_Shutdown();
    C.SDL_Quit();
    C.free(platform_state.platform_info.persistent_memory)
    C.free(platform_state.platform_info.temp_memory)
    C.free(platform_state.platform_info)
    C.free(platform_state)
  end

  return platform
end
  
