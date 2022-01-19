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

fn pallet_swap() {
    switch ( (tick.* & 0x00C0) >> 6 ) {
        0 => w4.PALETTE.* = g.pallet1,
        1 => w4.PALETTE.* = g.pallet12,
        2 => w4.PALETTE.* = g.pallet13,
        3 => w4.PALETTE.* = g.pallet14,
        // 2 => w4.PALETTE.* = g.pallet22,
        // 3 => w4.PALETTE.* = g.pallet2,
        else => |x| w4.tracef("Choose pallet: Unexpected value: %d", x),
    }
}
