/* Solo si NO puedes modificar el booter todavía:
   prueba 0x87E0_0000 antes que 0x8FE0_0000 (evita traps con -dtb)
   PERO: tocar direcciones no mapeadas igual te puede trapear.
   La solución buena es pasar a1.
*/
#include <stdint.h>
/* ... mismo UART + helpers ... */
static const uint32_t CAND_DTBS[] = { 0x87e00000u, 0x8fe00000u };
/* ... resto igual ... */
