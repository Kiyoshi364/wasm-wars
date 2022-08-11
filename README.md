# Wasm Wars

A Advance Wars Clone made for the [wasm4 Fantasy Console](https://wasm4.org).

# How to build and run from source

If you only want to play the game in your brouser consider [this link](https://shikiyo364.itch.io/wasm-wars).
Note ``zig`` is used to build the game (how to install: [site](https://ziglang.org/learn/getting-started/#installing-zig) [github](https://github.com/ziglang/zig/wiki/Building-Zig-From-Source)).
Also ``w4`` is necessary to run/or bundle the game (how to install: [site](https://wasm4.org/docs/getting-started/setup)).

To build the game:
```console
zig build -Drelease-small
```

Options after building:
- Run (browser):
```console
w4 run zig-out/lib/cart.wasm
```

- Run (as an executable):
```console
w4 run-native zig-out/lib/cart.wasm
```

- Bundle (create executabe/web page) (example for web page):
```console
w4 bundle zig-out/lib/cart.wasm --html index.html
```

# How to Play (Instructions)

 - If you are familiar to Advance Wars use *Keyboard X* as *Button A* and *Keyboard Z/C* as *Button B*.

 - Use arrows to move your cursor, *X* as yes/select and *Z/C* as no.

 - The objective is to eliminate all oponent's units.

 - After a Player finishes their turn, click on an empty ground to finish your turn.

 - Tip: the little car is an APC, it can transport foot soldiers (one at a time) by moving them into the APC's tile.

# Known Bugs
- Behavior
    - Loading a second unit into a transport unit (currently only APC)
    leaks (deletes but doesn't free the memory) the previous loaded unit
- Graphical
    - Evoking an menu on the farther right side,
    renders the menu off-screen

# Missing Features (Priority List)

### Important
- Initial Screen
- Graphics
    - More Units
    - Terrain
    - HQ / Cities

### Do-able
- Dinamic graphics for roads/rivers (corners, sideways, ...)
- Cities
    - Capture
    - Money

### Up next
- Building Units
    - Factory
    - Airport
    - Port
- Luck calculation (on combat)

### Bonus
- Help info
- Change Pallets
- Idle Animation

### Closer
- Unit movement
    - Animations
        - Unit moving (instead of teleporting)
        - Arrow showing Path
    - Proper fuel cost calculation
        * Use cursor path not the optimal
- Unit Combat
    - Ammo

### Farther
- Map Builder
- Fog of War
- CO's
    - day to day
        - attack bonus
        - defence bonus
        - others
    - star power
- Campaign
