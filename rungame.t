-- This is the best way to just run the game from the command line.

-- Dynamically load libraries.
terralib.linklibrary("libglfw3.dylib")
terralib.linklibrary("/System/Library/Frameworks/Cocoa.framework/Cocoa")
terralib.linklibrary("/System/Library/Frameworks/OpenGL.framework/OpenGL")
terralib.linklibrary("build/macosx64/gamedeps.dylib")

-- @TODO: Live looped recorded editing (fuck yeah)

function run()
  package.loaded.game = nil
  local game = require "game"
  
  local platform_api = require "glfw3_platform"
  local platform = generate_platform(true)

  local platform_state = platform.init()
  while platform.shouldKeepRunning(platform_state) do
    platform.mainLoop(platform_state, game.updateAndRender:getpointer())

    if platform_state.reload_requested then
      print("Reload Requested")
      package.loaded.game = nil
      game = require "game"
      
      platform_state.reload_requested = false
    end
    
  end
  platform.cleanup(platform_state)
end

run()
