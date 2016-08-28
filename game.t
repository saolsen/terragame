-- Main entrypoint for the actual game.
require "platform"

local game = {}

local struct GameState
{
  is_initialized : bool
  persistent_data : &uint8
}
game.gamestate_type = GameState

terra game.updateAndRender(platform : &PlatformInfo)
  var gamestate = [&GameState](platform.persistent_memory)
  if not gamestate.is_initialized then
    C.printf("Initializing\n")
    gamestate.persistent_data = platform.persistent_memory + sizeof(GameState)
    
    gamestate.is_initialized = true
  end
  
  C.nvgBeginPath(platform.vg);
  C.nvgRect(platform.vg, 15, 15, 15, 15);
  C.nvgFillColor(platform.vg, C.nvgRGBf(0,1,1));
  C.nvgFill(platform.vg);
end

return game
