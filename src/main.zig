const w4 = @import("wasm4.zig");

const g = @import("graphics.zig");

const mem = struct {
    const MAXSIZE = 58975;
    const mem_ptr = 0x19a0;
    const mem_buf = @intToPtr(*[MAXSIZE]u8, mem_ptr);

    fn incCreate(comptime T: type) comptime_int {
        return @sizeOf(T);
    }

    fn create(comptime i: comptime_int, comptime T: type) *T {
        const size = incCreate(T);
        if ( i + size > MAXSIZE ) {
            @compileLog("Type to alloc", T);
            @compileLog("Size to create", size);
            @compileLog("Before create", i);
            @compileLog("After create", i + size);
            @compileError("create: Not enough memory!");
        }
        return @intToPtr(*T, @ptrToInt(mem_buf) + i);
    }

    fn incAlloc(comptime amount: comptime_int, comptime T: type) comptime_int {
        return amount * @sizeOf(T);
    }

    fn alloc(comptime i: comptime_int, comptime amount: comptime_int, comptime T: type) *[amount]T {
        const size = incAlloc(amount, T);
        if ( i + size > MAXSIZE ) {
            @compileLog("Type to alloc", T);
            @compileLog("Size to alloc", size);
            @compileLog("Before alloc", i);
            @compileLog("After alloc", i + size);
            @compileError("alloc: Not enough memory!");
        }
        return @intToPtr(*[amount]T, @ptrToInt(mem_buf) + i);
    }
};

const ptrs = struct {
    tick: *u16,
    color: *u16,
    gpads: *[4]u8,
    map: *[map_size][map_size]u8,
    cam: *[2]u8,
    pos: *[2]u8,

    fn init() @This() {
        comptime var alloc = 0;

        const tick = mem.create(alloc, u16);
        alloc += mem.incCreate(u16);
        const color = mem.create(alloc, u16);
        alloc += mem.incCreate(u16);
        const gpads = mem.alloc(alloc, 4, u8);
        alloc += mem.incAlloc(4, u8);
        const map = mem.alloc(alloc, map_size, [map_size]u8);
        alloc += mem.incAlloc(map_size, [map_size]u8);
        const cam = mem.alloc(alloc, 2, u8);
        alloc += mem.incAlloc(2, u8);
        const pos = mem.alloc(alloc, 2, u8);
        alloc += mem.incAlloc(2, u8);

        return .{
            .tick = tick,
            .color = color,
            .gpads = gpads,
            .map = map,
            .cam = cam,
            .pos = pos,
        };
    }
}.init();

// Map
const tilespace = 16;
const map_size = 16;
const screen_tiles = 10;

fn bg_chess(size: u3) usize {
    return switch (size) {
        0 => 1,
        1 => 2,
        2 => 4,
        3 => 5,
        4 => 8,
        5 => 10,
        6 => 20,
        7 => 6400,
    };
}

fn bg_lines(size: u3) usize {
    return switch (size) {
        0 => 40,
        1 => 80,
        2 => 160,
        3 => 200,
        4 => 320,
        5 => 400,
        6 => 3200,
        7 => 6400,
    };
}

fn background() void {
    const canvasSize = w4.CANVAS_SIZE / 4;
    const size = bg_chess(2);
    const clr: u8 =  0x44;
    const clr2: u8 = 0xBB;

    var cnt: isize = -1;
    for ( w4.FRAMEBUFFER ) |*c, index| {
        c.* = blk: {
            const i = index / size;
            const y: usize = (i/4) / canvasSize;
            const x: usize = (i  ) % canvasSize;
            const ok = (x + y) & 1 == 0;
            if ( i > cnt ) {
                cnt = @intCast(isize, i);
            }
            break :blk if ( ok ) clr else clr2;
        };
    }
}

export fn start() void {
    ptrs.map[7][8] = 1;
    ptrs.pos[0] = 1;
    ptrs.pos[1] = 1;
    {
        var i: u8 = 0;
        var j: u8 = 0;
        while ( j < map_size ) : ( j += 1 ) {
            i = 0;
            while ( i < map_size ) : ( i += 1 ) {
                if ( i == 0 or i == map_size-1 or j == 0 or j == map_size-1 ) {
                    ptrs.map[j][i] = 1;
                }
            }
        }
    }

    w4.SYSTEM_FLAGS.* = w4.SYSTEM_PRESERVE_FRAMEBUFFER;

    // w4.tone(10, 60, 100, 0);
    w4.tone(262 | (253 << 16), 60, 30, w4.TONE_PULSE1 | w4.TONE_MODE3);
}

export fn update() void {
    const gpads = ptrs.gpads;
    const cam = ptrs.cam;
    const pos = ptrs.pos;

    const pad_old = gpads[0];
    const pad_new = w4.GAMEPAD1.*;
    const pad_diff = pad_old ^ pad_new;

    if ( pad_diff & w4.BUTTON_DOWN == w4.BUTTON_DOWN
        and pad_new & w4.BUTTON_DOWN == w4.BUTTON_DOWN ) {
        pos[1] += 1;
    } else if ( pad_diff & w4.BUTTON_UP == w4.BUTTON_UP
        and pad_new & w4.BUTTON_UP == w4.BUTTON_UP ) {
        pos[1] -= 1;
    }

    if ( pad_diff & w4.BUTTON_RIGHT == w4.BUTTON_RIGHT
        and pad_new & w4.BUTTON_RIGHT == w4.BUTTON_RIGHT ) {
        pos[0] += 1;
    } else if ( pad_diff & w4.BUTTON_LEFT == w4.BUTTON_LEFT
        and pad_new & w4.BUTTON_LEFT == w4.BUTTON_LEFT ) {
        pos[0] -= 1;
    }

    gpads[0] = pad_new;

    // Camera movement
    const cam_max = map_size - screen_tiles;
    const xdiff = @intCast(i8, pos[0]) - @intCast(i8, cam[0]);
    if ( 0 <= cam[0] and cam[0] < cam_max and xdiff > screen_tiles - 2 ) {
        cam[0] += 1;
    } else if ( 0 < cam[0] and cam[0] <= cam_max and xdiff < 2 ) {
        cam[0] -= 1;
    }
    const ydiff = @intCast(i8, pos[1]) - @intCast(i8, cam[1]);
    if ( 0 <= cam[1] and cam[1] < cam_max and ydiff > screen_tiles - 2 ) {
        cam[1] += 1;
    } else if ( 0 < cam[1] and cam[1] <= cam_max and ydiff < 2 ) {
        cam[1] -= 1;
    }

    draw();
}

fn draw() void {
    background();
    draw_map();

    const pos = ptrs.pos;

    {
        const x = pos[0] * tilespace + 4;
        const y = pos[1] * tilespace + 4;
        blit(&g.smiley, x, y, 8, 8, 0);
    }

    const tick = ptrs.tick;
    tick.* +%= 1;


    switch ( (tick.* & 0x00C0) >> 6 ) {
        0 => w4.PALETTE.* = g.pallet1,
        1 => w4.PALETTE.* = g.pallet12,
        2 => w4.PALETTE.* = g.pallet13,
        3 => w4.PALETTE.* = g.pallet14,
        // 2 => w4.PALETTE.* = g.pallet22,
        // 3 => w4.PALETTE.* = g.pallet2,
        else => |x| w4.tracef("Choose pallet: Unexpected value: %d", x),
    }

    blit(&g.smiley, 50, 50, 8, 8, w4.BLIT_FLIP_X | w4.BLIT_ROTATE);
}

fn draw_map() void {
    var cx: u8 = ptrs.cam[0];
    var cy: u8 = ptrs.cam[1];

    const ts = tilespace;
    const map = ptrs.map;

    var i: u8 = 0;
    var j: u8 = 0;
    while ( j < map_size ) : ( j += 1 ) {
        i = 0;
        while ( i < map_size ) : ( i += 1 ) {
            const tile = map[cy+j][cx+i];
            if ( tile == 1 ) {
                w4.DRAW_COLORS.* = 0x4;
                blit(&g.square, (cx+i)*ts    , (cy+j)*ts    , 8, 8, 0);
                blit(&g.square, (cx+i)*ts    , (cy+j)*ts + 8, 8, 8, 0);
                blit(&g.square, (cx+i)*ts + 8, (cy+j)*ts    , 8, 8, 0);
                blit(&g.square, (cx+i)*ts + 8, (cy+j)*ts + 8, 8, 8, 0);
            }
        }
    }
}

fn blit(sprite: [*]const u8, x: i32, y: i32, width: i32, height: i32, flags: u32) void {
    w4.blit(sprite,
        x - (ptrs.cam[0]*tilespace),
        y - (ptrs.cam[1]*tilespace),
        width, height, flags);
}
