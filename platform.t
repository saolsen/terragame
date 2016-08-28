C = terralib.includecstring([[
#include <stdio.h>
#include "./thirdparty/nanovg/src/nanovg.h"
]], {"-O2"})

-- Data managed by the platform layer and passed to the game each frame.
struct PlatformInfo
{
  persistent_memory : &uint8
  persistent_memory_capacity : uint32

  temp_memory : &uint8
  temp_memory_capacity : uint32
  
  window_width : int
  window_height : int
  
  display_width : int
  display_height : int

  dt : float
  ticks : int16

  vg : &C.NVGcontext
}
