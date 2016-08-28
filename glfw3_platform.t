local C = terralib.includecstring([[
#include <stdio.h>
#include "./thirdparty/include/glew.h"
#include <GLFW/glfw3.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreturn-type"

#include "./thirdparty/nanovg/src/nanovg.h"
#define NANOVG_GL3_IMPLEMENTATION
#include "./thirdparty/nanovg/src/nanovg_gl.h"

#pragma clang diagnostic pop
]], {"-O2"})

-- Generates a platform layer for a game.
function generate_platform(dynamic_runtime)
  require "platform"

  local struct PlatformState
  {
    window : &C.GLFWwindow
    vg : &C.NVGcontext
    reload_requested : bool
    platform_info : &PlatformInfo
  }

  local platform = {}
  -- @TODO: Compile this stuff seperately probably.
  -- terralib.includec("./thirdparty/include/glew.c")
  -- terralib.includec("./thirdparty/nanovg/src/nanovg.c")

  local terra errorCallback(error : int, description : &int8)
    C.printf(description)
  end

  terra platform.init() : &PlatformState
    var platform_state = [&PlatformState](C.malloc(sizeof(PlatformState)))
    platform_state.window = nil
    platform_state.vg = nil
    platform_state.reload_requested = false

    -- Initialize glfw.
    if C.glfwInit() == 0 then
      C.printf("Error initializing glfw")
      return nil;
    end

    C.glfwSetErrorCallback(errorCallback)
    
    C.glfwWindowHint(C.GLFW_CONTEXT_VERSION_MAJOR, 3)
    C.glfwWindowHint(C.GLFW_CONTEXT_VERSION_MINOR, 2)
    C.glfwWindowHint(C.GLFW_OPENGL_FORWARD_COMPAT, C.GL_TRUE)
    C.glfwWindowHint(C.GLFW_OPENGL_PROFILE, C.GLFW_OPENGL_CORE_PROFILE)

    C.glfwWindowHint(C.GLFW_DOUBLEBUFFER, C.GL_TRUE)
    C.glfwWindowHint(C.GLFW_DEPTH_BITS, 24)
    C.glfwWindowHint(C.GLFW_STENCIL_BITS, 8)

    platform_state.window = C.glfwCreateWindow(1024, 768, "hello world", nil, nil)

    if platform_state.window == nil then
      C.printf("Error creating window.")
      C.glfwTerminate()
      return nil
    end

    C.glfwMakeContextCurrent(platform_state.window)
    C.printf("Created window")

    C.glewExperimental = C.GL_TRUE;
    C.glewInit()
    C.glGetError()

    C.glfwSwapInterval(1)

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
    
    return platform_state
  end

  terra platform.shouldKeepRunning(platform_state : &PlatformState) : bool
    return C.glfwWindowShouldClose(platform_state.window) == 0
  end

  -- @NOTE: I really do like sdl a lot better and I think the dream of static binary is dead
  -- anyway, I should just switch to sdl.
  terra platform.mainLoop(platform_state : &PlatformState,
                          updateAndRender : {&PlatformInfo} -> {}) : &PlatformState
    C.glfwPollEvents()

    -- @TODO: This code is only for running through terra, not for standalone.
    -- glfw fuckin sucks for this shit... reason enough to switch to sdl.
    if C.glfwGetKey(platform_state.window, C.GLFW_KEY_R) == C.GLFW_PRESS then
      platform_state.reload_requested = true
    end

    var ratio : float
    var window_width : int32
    var window_height : int32
    C.glfwGetWindowSize(platform_state.window, &window_width, &window_height)
    
    platform_state.platform_info.window_width = window_width
    platform_state.platform_info.window_height = window_height

    var display_width : int32
    var display_height : int32
    C.glfwGetWindowSize(platform_state.window, &display_width, &display_height)
    
    platform_state.platform_info.display_width = display_width
    platform_state.platform_info.display_height = display_height

    -- @TODO: how to divide?
    ratio = [float](display_width) / [float](display_height)

    C.glClear(C.GL_COLOR_BUFFER_BIT
                or C.GL_DEPTH_BUFFER_BIT
                or C.GL_STENCIL_BUFFER_BIT)
    C.nvgBeginFrame(platform_state.vg, window_width, window_height, display_width/window_width);

    updateAndRender(platform_state.platform_info)
    
    C.nvgBeginPath(platform_state.vg);
    C.nvgRect(platform_state.vg, 10, 10, 1004, 748);
    C.nvgStrokeColor(platform_state.vg, C.nvgRGBf(1,0,0));
    C.nvgStroke(platform_state.vg);

    C.nvgEndFrame(platform_state.vg)

    C.glfwSwapBuffers(platform_state.window)

  end

  terra platform.cleanup(platform_state : &PlatformState)
    C.glfwDestroyWindow(platform_state.window)
    C.glfwTerminate()
    C.free(platform_state.platform_info)
    C.free(platform_state)
  end

  return platform

end


-- main()

-- -- This is how you can compile it in osx.
-- flags = {"-l", "glfw3",
--          "-framework", "Cocoa",
--          "-framework", "OpenGL",
--          "-framework", "IOKit",
--          "-framework", "CoreVideo",
--          "-l", "deps"}
-- terralib.saveobj("thegame", {main = main})
