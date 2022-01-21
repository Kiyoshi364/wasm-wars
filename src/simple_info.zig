// Terrain
pub const Map_Tile = enum {
    plains, woods, mountain, road, // bridge,
    sea, // reefs, beach, river,
    // pipe, pipe_seam, pipe_broken,
    hq, city, factory, // airport, port,
    // com_tower, lab,

    const Self = @This();
    pub fn defence(self: Self) Defence {
        return comptime blk: {
            break :blk switch (self) {
                .road, .bridge, .sea, => 0,
                .plains, => 1,
                .woods, => 2,
                .city, .factory, => 3,
                .mountain, .hq, => 4,
            };
        };
    }

    pub fn move_cost(self: Self, typ: Move_Type) ?Cost {
        return comptime blk: {
            break :blk switch (typ) {
                .infantry => switch (self) {
                    .plains, .woods, .road,
                    // .bridge, .beach,
                    .hq, .city, .factory, // .airport, .port,
                    // .com_tower, .lab,
                        => @as(?Cost, 1),
                    // .river,
                    .mountain, => @as(Cost, 2),
                    .sea, // .reefs,
                    // .pipe, .pipe_seam, .pipe_broken,
                        => null,
                },
                .mech => switch (self) {
                    .plains, .woods, .mountain, .road,
                    // .bridge, .beach, .river,
                    .hq, .city, .factory, // .airport, .port,
                    // .com_tower, .lab,
                        => @as(?Cost, 1),
                    .sea, // .reefs,
                    // .pipe, .pipe_seam, .pipe_broken,
                        => null,
                },
            };
        };
    }
};

pub const Defence = u3;

// Units
pub const Unity_Id = enum {
    infantry, mech, // recon, apc
    // tank, md_tank, neo_tank,
    // artillery, rockets,
    // anti_air, missiles,
    // b_copter, t_copter, fighter, bomber,
    // lander, cruiser, sub, b_ship,

    const Self = @This();

    pub const cnt = @typeInfo(Self).Enum.fields.len;

    pub fn move_cost(self: Self) Move_Cost {
        return comptime blk: {
            break :blk switch (self) {
                .infantry => Move_Cost{ .typ = .infantry, .moves = 3 },
                .mech     => Move_Cost{ .typ = .mech    , .moves = 2 },
            };
        };
    }

    pub fn attack(self: Self, other: Self) Damage {
        return comptime blk: {
            break :blk switch (self) {
                .infantry => switch (other) {
                    .infantry => @as(Damage, 55),
                    .mech     => @as(Damage, 45),
                },
                .mech => switch (other) {
                    .infantry => @as(Damage, 65),
                    .mech     => @as(Damage, 55),
                },
            };
        };
    }
};

pub const Move_Type = enum {
    infantry, mech,
    // .tires .treads,
    // .air,
    // .ship, .lander,
};

pub const Move_Cost = struct {
    typ: Move_Type,
    moves: Cost,
};

pub const Cost = u4;
pub const Damage = u8;
