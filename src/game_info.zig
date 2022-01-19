// Terrain
pub const Map_Tile = enum {
    plains, woods, mountain, road, bridge,
    sea, reefs, beach, river,
    pipe, pipe_seam, pipe_broken,
    hq, city, factory, airport, port,
    com_tower, lab,

    const Self = @This();
    pub fn defence(self: Self) Defence {
        return switch (self) {
            .road, .bridge, .sea, .beach, .river,
                .pipe, .pipe_seam, => 0,
            .plains, .reefs, .pipe_broken, => 1,
            .woods, => 2,
            .city, .factory, .airport, .port,
            .com_tower, .lab, => 3,
            .mountain, .hq, => 4,
        };
    }
};

pub const tile_info = build._tile_info();

pub const Defence = u3;
pub const Move_Cost = [Move_Type]u2;
pub const Tile_Info = struct {
    defence: Defence,
    move_cost: Move_Cost,
};

// Units
const Unity_Id = enum {
    infantry, mech, recon, apc
    tank, md_tank, neo_tank,
    artillery, rockets,
    anti_air, missiles,
    b_copter, t_copter, fighter, bomber,
    lander, cruiser, sub, b_ship,
};

// Build
const build = struct {
    const Tile_info = [@typeInfo(Map_Tile).Enum.fields.len]Tile_Info;
    fn _tile_info() Tile_info {
        comptime var arr: Tile_info = undefined;
        for (@typeInfo(Map_Tile).Enum.fields) |field| {
            const i = field.value;
            const tile = @intToEnum(Map_Tile, i);
            arr[i] = Tile_Info{
                .defence = tile.defence(),
            };
        }
        return arr;
    }
};
