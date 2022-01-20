pub const Letter = enum {
    a, b, c, d, e, f, g, h, i, j,
    k, l, m, n, o, p, q, r, s, t,
    u, v, w, x, y, z, n0, n1, n2,
    n3, n4, n5, n6, n7, n8, n9,

    const Self = @This();

    pub fn fromChar(comptime c: u8) Self {
        return switch (c) {
            'a','A' => .a, 'b','B' => .b, 'c','C' => .c,
            'd','D' => .d, 'e','E' => .e, 'f','F' => .f,
            'g','G' => .g, 'h','H' => .h, 'i','I' => .i,
            'j','J' => .j, 'k','K' => .k, 'l','L' => .l,
            'm','M' => .m, 'n','N' => .n, 'o','O' => .o,
            'p','P' => .p, 'q','Q' => .q, 'r','R' => .r,
            's','S' => .s, 't','T' => .t, 'u','U' => .u,
            'v','V' => .v, 'w','W' => .w, 'x','X' => .x,
            'y','Y' => .y, 'z','Z' => .z,
            '0' => .n0, '1' => .n1, '2' => .n2, '3' => .n3,
            '4' => .n4, '5' => .n5, '6' => .n6, '7' => .n7,
            '8' => .n8, '9' => .n9,
            else => {
                @compileLog(c);
                @compileError("Unsupported character graphics!");
            },
        };
    }

    pub fn toGraphics(comptime self: Self) [4]u8 {
        return comptime blk: {
            break :blk switch (self) {
                .a => A, .b => B, .c => C, .d => D, .e => E,
                .f => F, .g => G, .h => H, .i => I, .j => J,
                .k => K, .l => L, .m => M, .n => N, .o => O,
                .p => P, .q => Q, .r => R, .s => S, .t => T,
                .u => U, .v => V, .w => W, .x => X, .y => Y,
                .z => Z,
                .n0 => n0, .n1 => n1, .n2 => n2, .n3 => n3,
                .n4 => n4, .n5 => n5, .n6 => n6, .n7 => n7,
                .n8 => n8, .n9 => n9,
            };
        };
    }
};

pub fn encode(comptime text: []const u8) [text.len]?[4]u8 {
    comptime var graphics: [text.len]?[4]u8 = undefined;
    inline for (text) |c, i| {
        comptime {
            if ( c == ' ' ) {
                graphics[i] = null;
            } else {
                graphics[i] = Letter.fromChar(c).toGraphics();
            }
        }
    }
    return graphics;
}

pub const A = [4]u8{
    0b11011111,
    0b10101111,
    0b10001111,
    0b10101111,
};

pub const B = [4]u8{
    0b10111111,
    0b10001111,
    0b10101111,
    0b10001111,
};

pub const C = [4]u8{
    0b10001111,
    0b10111111,
    0b10111111,
    0b10001111,
};

pub const D = [4]u8{
    0b10011111,
    0b10101111,
    0b10101111,
    0b10011111,
};

pub const E = [4]u8{
    0b10001111,
    0b10001111,
    0b10111111,
    0b10001111,
};

pub const F = [4]u8{
    0b10001111,
    0b10111111,
    0b10011111,
    0b10111111,
};

pub const G = [4]u8{
    0b10001111,
    0b10111111,
    0b10101111,
    0b10001111,
};

pub const H = [4]u8{
    0b10111111,
    0b10111111,
    0b10001111,
    0b10101111,
};

pub const I = [4]u8{
    0b10001111,
    0b11011111,
    0b11011111,
    0b10001111,
};

pub const J = [4]u8{
    0b10001111,
    0b11101111,
    0b10101111,
    0b10011111,
};

pub const K = [4]u8{
    0b10101111,
    0b10011111,
    0b10011111,
    0b10101111,
};

pub const L = [4]u8{
    0b10111111,
    0b10111111,
    0b10111111,
    0b10001111,
};

pub const M = [4]u8{
    0b10101111,
    0b10001111,
    0b10101111,
    0b10101111,
};

pub const N = [4]u8{
    0b11111111,
    0b10001111,
    0b10101111,
    0b10101111,
};

pub const O = [4]u8{
    0b10001111,
    0b10101111,
    0b10101111,
    0b10001111,
};

pub const P = [4]u8{
    0b10001111,
    0b10001111,
    0b10111111,
    0b10111111,
};

pub const Q = [4]u8{
    0b10001111,
    0b10101111,
    0b10001111,
    0b11101111,
};

pub const R = [4]u8{
    0b10001111,
    0b10101111,
    0b10011111,
    0b10101111,
};

pub const S = [4]u8{
    0b10001111,
    0b10111111,
    0b11101111,
    0b10001111,
};

pub const T = [4]u8{
    0b10001111,
    0b11011111,
    0b11011111,
    0b11011111,
};

pub const U = [4]u8{
    0b10101111,
    0b10101111,
    0b10101111,
    0b10001111,
};

pub const V = [4]u8{
    0b10101111,
    0b10101111,
    0b10101111,
    0b11011111,
};

pub const W = [4]u8{
    0b11111111,
    0b10101111,
    0b10101111,
    0b11011111,
};

pub const X = [4]u8{
    0b10101111,
    0b11011111,
    0b11011111,
    0b10101111,
};

pub const Y = [4]u8{
    0b10101111,
    0b11011111,
    0b11011111,
    0b11011111,
};

pub const Z = [4]u8{
    0b10001111,
    0b11011111,
    0b10111111,
    0b10001111,
};

pub const n0 = [4]u8{
    0b10001111,
    0b10001111,
    0b10101111,
    0b10001111,
};

pub const n1 = [4]u8{
    0b11011111,
    0b10011111,
    0b11011111,
    0b10001111,
};

pub const n2 = [4]u8{
    0b10001111,
    0b11101111,
    0b10011111,
    0b10001111,
};

pub const n3 = [4]u8{
    0b10001111,
    0b11001111,
    0b11101111,
    0b10001111,
};

pub const n4 = [4]u8{
    0b10101111,
    0b10001111,
    0b11101111,
    0b11101111,
};

pub const n5 = [4]u8{
    0b10001111,
    0b10011111,
    0b11101111,
    0b10001111,
};

pub const n6 = [4]u8{
    0b10001111,
    0b10111111,
    0b10001111,
    0b10001111,
};

pub const n7 = [4]u8{
    0b10001111,
    0b11101111,
    0b11101111,
    0b11101111,
};

pub const n8 = [4]u8{
    0b10001111,
    0b10101111,
    0b10001111,
    0b10001111,
};

pub const n9 = [4]u8{
    0b10001111,
    0b10001111,
    0b11101111,
    0b10001111,
};
