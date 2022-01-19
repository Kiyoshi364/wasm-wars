// Terrain
pub const Map_Tile = enum {
    plains, woods, mountain, road, // bridge,
    sea, // reefs, beach, river,
    // pipe, pipe_seam, pipe_broken,
    hq, city, factory, // airport, port,
    // com_tower, lab,

    const Self = @This();
    pub fn defence(self: Self) Defence {
        return switch (self) {
            .road, .bridge, .sea, => 0,
            .plains, => 1,
            .woods, => 2,
            .city, .factory, => 3,
            .mountain, .hq, => 4,
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

    pub fn range(self: Self) Range {
        return switch (self) {
            .infantry => 3,
            .mech => 2,
        };
    }

    pub fn attack(self: Self, other: Self) Damage {
        const table = [cnt][cnt]Damage{
            .{ 55, 45, },
            .{ 65, 55, },
        };
        return table[@enumToInt(self)][@enumToInt(other)];
    }
};

pub const Range = u8;
pub const Damage = u8;
