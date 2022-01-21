// Terrain
pub const Map_Tile = enum {
    plains, woods, mountain, road, // bridge,
    sea, // reefs, beach, river,
    // pipe, pipe_seam, pipe_broken,
    hq, city, factory, // airport, port,
    // miss_silo, com_tower, lab,

    const Self = @This();
    pub fn defense(self: Self) Defense {
        return switch (self) {
            .road, .sea, => 0,
            .plains, => 1,
            .woods, => 2,
            .city, .factory, => 3,
            .mountain, .hq, => 4,
        };
    }

    pub fn move_cost(self: Self, typ: Move_Type) ?Cost {
        return switch (typ) {
            .infantry => switch (self) {
                .plains, .woods, .road,
                // .bridge, .beach,
                .hq, .city, .factory, // .airport, .port,
                // .miss_silo, .com_tower, .lab,
                    => @as(?Cost, 1),
                // .river,
                .mountain, => @as(?Cost, 2),
                .sea, // .reefs,
                // .pipe, .pipe_seam, .pipe_broken,
                    => null,
            },
            .mech => switch (self) {
                .plains, .woods, .mountain, .road,
                // .bridge, .beach, .river,
                .hq, .city, .factory, // .airport, .port,
                // .miss_silo, .com_tower, .lab,
                    => @as(?Cost, 1),
                .sea, // .reefs,
                // .pipe, .pipe_seam, .pipe_broken,
                    => null,
            },
            .treads => switch (self) {
                .plains, .road,
                // .bridge, .beach,
                .hq, .city, .factory, // .airport, .port,
                // .miss_silo, .com_tower, .lab,
                    => @as(?Cost, 1),
                .woods, => @as(?Cost, 2),
                .mountain, // .river,
                .sea, // .reefs,
                // .pipe, .pipe_seam, .pipe_broken,
                    => null,
            }
        };
    }
};

pub const Defense = u3;

// Units
pub const Unity_Id = enum {
    infantry, mech, // recon,
    apc,
    // tank, md_tank, neo_tank,
    // artillery, rockets,
    // anti_air, missiles,
    // b_copter, t_copter, fighter, bomber,
    // lander, cruiser, sub, b_ship,

    const Self = @This();

    pub const cnt = @typeInfo(Self).Enum.fields.len;

    pub fn move_cost(self: Self) Move_Cost {
        return switch (self) {
            .infantry => Move_Cost{ .typ = .infantry, .moves = 3 },
            .mech     => Move_Cost{ .typ = .mech    , .moves = 2 },
            .apc      => Move_Cost{ .typ = .treads  , .moves = 6 },
        };
    }

    pub fn may_transport(self: Self, other: Self) bool {
        return switch (self) {
            .apc => switch (other) {
                .infantry, .mech => true,
                else => false,
            },
            else => false,
        };
    }

    pub fn max_fuel(self: Self) Fuel {
        return switch (self) {
            .infantry => 99,
            .mech     => 70,
            .apc      => 70,
        };
    }

    pub fn attack(self: Self, other: Self) ?Damage {
        return switch (self) {
            .infantry => switch (other) {
                .infantry => @as(Damage, 55),
                .mech     => @as(Damage, 45),
                .apc      => @as(Damage, 14),
            },
            .mech => switch (other) {
                .infantry => @as(Damage, 65),
                .mech     => @as(Damage, 55),
                .apc      => @as(Damage, 75),
            },
            .apc => null,
        };
    }
};

pub const Move_Type = enum {
    infantry, mech,
    // tires,
    treads,
    // air,
    // ship, lander,
};

pub const Move_Cost = struct {
    typ: Move_Type,
    moves: Cost,
};

pub const Cost = u4;
pub const Fuel = u7;
pub const Damage = u7;
