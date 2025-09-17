
# El Último Bocado

El Último Bocado es un juego 2D de combate por turnos inspirado en Worms, donde dos personajes (Saltenia y Tucumana) se enfrentan usando proyectiles y el entorno destructible. Inspirado en juegos como Worms, el objetivo es derrotar al oponente usando habilidades, física y estrategia.


## Características principales

- **Combate por turnos**: Dos jugadores (o jugador vs bot) se alternan para moverse y atacar.
- **Entorno destructible**: El escenario puede ser destruido por explosiones, cambiando la estrategia de cada turno.
- **Proyectiles y armas**: Cada personaje puede lanzar proyectiles con diferentes efectos y daños.
- **Animaciones y efectos visuales**: Personajes animados, explosiones y efectos de daño.
- **Pantalla de resultado**: Al morir un jugador, se muestra el ganador y opción de reiniciar.

## Estructura del proyecto

- `Menu/`: Menú principal, título y créditos.
- `assets/`: Imágenes de personajes, armas, explosiones y fondos.
- `src/character/`: Lógica y escenas de los personajes jugables.
- `src/destruction/`: Sistema de destrucción del terreno.
- `src/levels/`: Niveles jugables, zona de muerte y pantalla de resultado.
- `src/scripts/`: Controlador de juego, cámara y menú.
- `src/weapons/`: Proyectiles, explosiones y lógica de daño.

## Cómo jugar

1. Ejecuta el proyecto en Godot Engine (versión 4.x recomendada).
2. En el menú principal, elige jugar contra un amigo o contra el bot.
3. Cada jugador controla un mago (Saltenia o Tucumana):
	- Usa **A/D** para moverte a izquierda/derecha.
	- Usa **Espacio** para saltar.
	- Apunta con el mouse y haz clic para cargar y disparar el proyectil.
	- El turno termina al disparar; el siguiente jugador/bot toma su turno.
4. El objetivo es reducir la vida del oponente a 0 usando proyectiles y aprovechando el entorno destructible.
5. Si un jugador cae en la zona de muerte o su vida llega a 0, el otro gana.

## Controles

- **Moverse**: A/D
- **Saltar**: Espacio
- **Apuntar y disparar**: Mouse (clic izquierdo)

## Créditos

- Ricardo Valencia
- Alexander Cruz
- Mariana Del Arroyo

## Requisitos y ejecución

- Godot Engine 4.x
- No requiere instalación de dependencias externas.
- Abre el proyecto con Godot y ejecuta la escena principal (`Menu/main_menu.tscn`).

## Notas técnicas

- El sistema de destrucción usa viewports y shaders para modificar el terreno en tiempo real.
- El controlador de juego gestiona turnos, input, y la lógica de victoria/derrota.
- El menú permite elegir modo de juego y muestra créditos.

---
> Este proyecto toma como referencia la estructura y mecánicas del repositorio educativo Spell-Splosion (Godot).
