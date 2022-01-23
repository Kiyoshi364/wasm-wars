pub const w4 = @import("wasm4.zig");

const g = @import("graphics.zig");
pub const info = @import("simple_info.zig");
const alphabet = @import("alphabet.zig");
const obj = @import("obj.zig");

// Input
const gpad_timer_max = 13;

// Map
const tilespace = 16;
const map_size_x = 15;
const map_size_y = 10;
const screen_tiles_x = 10;
const screen_tiles_y =
    if (screen_tiles_x < map_size_y) screen_tiles_x else map_size_y;

// Objs / Things
const obj_cnt = 100;

// selection
const selected_range = 19;

// menus
const day_menu = new_menu( .day_menu, &[_][]const u8{
    // "CO",
    // "Intel",
    // "Optns",
    // "Save",
    "Cancel",
    "End Day",
});

pub const ptrs = struct {
    gpads: *[4]u8,
    gpads_timer: *[4][4]u4,

    redraw: *bool,

    map: *[map_size_y][map_size_x]info.Map_Tile,
    cam: *[2]u8,

    curr_day: *u8,
    curr_team: *Team,
    team_num: *Team,

    cursor_pos: *[2]u8,
    cursor_state: *Cursor_State,
    cursor_menu: *Loopable,

    selec_offset: *[2]u8,
    selected: *[selected_range][selected_range]?info.Cost,
    selec_obj: *ObjId,
    selec_pos: *[2]u8,

    moved_contex: *Moved_Contex,

    unloaded_menu: *Loopable,
    unloaded: *Loopable,
    unloaded_buff: *[4][2]u8,

    attacked: *Loopable,
    attac_buff: *[4]ObjId,

    next_obj: *ObjId,
    obj_id: *[obj_cnt]info.Unity_Id,
    obj_info: *[obj_cnt]ObjInfo,
    obj_pos: *[2][obj_cnt]u8,
    obj_map: *[map_size_y][map_size_x]?ObjId,

    freed_cnt: *ObjId,
    freed_list: *[obj_cnt]ObjId,

    const Self = @This();
    const std = @import("std");

    pub const MAXSIZE = 58975;
    const mem_ptr = 0x19a0;
    const mem_buf = @intToPtr(*[MAXSIZE]u8, mem_ptr);

    pub const alloced_memory = calc_used();

    fn init() Self {
        comptime var self: Self = undefined;
        comptime var alloc = 0;

        inline for (@typeInfo(Self).Struct.fields) |field| {
            const T = @typeInfo(field.field_type).Pointer.child;
            switch (@typeInfo(T)) {
                .Int, .Bool, .Array, .Struct, .Enum => {
                    const size = @sizeOf(T);
                    if ( alloc + size > MAXSIZE ) {
                        @compileLog("Type to alloc", T);
                        @compileLog("Size to alloc", size);
                        @compileLog("Before alloc", alloc);
                        @compileLog("After alloc", alloc + size);
                        @compileError("ptrs.init: Not enough memory!");
                    }
                    @field(self, field.name) = @intToPtr(*T, mem_ptr + alloc);
                    alloc += size;
                },
                else => {
                    @compileLog(field.name, T);
                    @compileError("ptrs: unhandled case.\nIf you got this compileError, consider adding a case for the unhandled type.");
                },
            }
        }
        return self;
    }

    fn calc_used() comptime_int {
        comptime var alloc = 0;
        inline for (@typeInfo(Self).Struct.fields) |field| {
            const T = @typeInfo(field.field_type).Pointer.child;
            const size = @sizeOf(T);
            alloc += size;
        }
        return alloc;
    }
}.init();

pub const Team = u2;

const Cursor_State = enum(u8) {
    initial = 0,
    selected,
    moved,
    unload_menu,
    unload,
    attack,
    day_menu,
};

const Loopable = struct{
    i: u4, max: u4,
    const Self = @This();
    fn inc(self: *Self) void {
        self.*.i = (self.*.i + 1) % self.*.max;
    }
    fn dec(self: *Self) void {
        self.*.i = (self.*.i -% 1 +% self.*.max) % self.*.max;
    }
};

const Moved_Contex = packed struct {
    @"capture": bool = false,
    @"no fire": bool = false,
    @"fire"   : bool = false,
    @"unload" : bool = false,
    @"supply" : bool = false,
    @"join"   : bool = false,
    @"load"   : bool = false,
    @"wait"   : bool = false,
};

fn MvdCtxEnum() type {
    const fields = @typeInfo(Moved_Contex).Struct.fields;
    comptime var texts: [fields.len][]const u8 = undefined;
    inline for ( fields ) |f, i| {
        texts[i] = f.name;
    }
    return createEnum(&texts);
}

pub const max_health = 100;

const ObjInfo = struct {
    acted: bool,
    team: Team,
    health: u7,
    fuel: info.Fuel,
    transporting: ?ObjId,
};

pub const ObjId = u7;

fn createEnum(texts: []const[]const u8) type {
    const TP = @import("std").builtin.TypeInfo;
    const EF = TP.EnumField;
    const Decl = TP.Declaration;
    const decls = [0]Decl{};

    comptime var enum_f: [texts.len]EF = undefined;
    inline for ( texts ) |t, i| {
        enum_f[i] = .{ .name = t, .value = i, };
    }
    return @Type(.{ .Enum = .{
        .layout = .Auto, .tag_type = u8, .fields = &enum_f,
        .decls = &decls, .is_exhaustive = true,
    } });
}

fn new_menu(comptime tag: Cursor_State, texts: []const []const u8) type {
    comptime var max_len: u8 = 0;
    inline for ( texts ) |t| {
        if ( t.len > max_len ) max_len = t.len;
    }
    const block_cnt = max_len / 2 + 1;
    return struct {
        const Enum: type = createEnum(texts);
        const tag: Cursor_State = tag;
        const texts: [][]const u8 = texts;
        const block_cnt: u8 = block_cnt;
        const size: u8 = texts.len;

        fn name(i: u8) Enum {
            return @intToEnum(Enum, i);
        }

        fn draw() void {
            const x = @as(i32, ptrs.cursor_pos[0]) * tilespace;
            const y = @as(i32, ptrs.cursor_pos[1]) * tilespace;

            const xa = x + tilespace;
            const ya = y + 8 * ptrs.cursor_menu.*.i;
            const off = 2;

            w4.DRAW_COLORS.* = 0x01;
            var j: u8 = 0;
            while ( j < size ) : ( j += 1 ) {
                var i: u8 = 0;
                while ( i < block_cnt ) : ( i += 1 ) {
                    blit(&g.square, xa + i * 8, y + j * 8, 8, 8, 0);
                }
            }
            w4.DRAW_COLORS.* = 0x02;
            inline for ( texts ) |t, i| {
                text(t, xa + off, y + off + @intCast(i32, i) * 8);
            }

            w4.DRAW_COLORS.* = 0x03;
            blit(&g.select_thin_q, xa, ya, 8, 8, 0);
            blit(&g.select_thin_q, xa + 8 * (block_cnt - 1), ya, 8, 8, 6);
        }
    };
}

export fn start() void {
    // Debug allocated memory
    w4.tracef("Memory Usage:\n  Allocated:    %d\n  Free for use: %d" ++
        "\n  Use (%%): %f",
        @as(i32, @TypeOf(ptrs).alloced_memory),
        @as(i32, @TypeOf(ptrs).MAXSIZE - @TypeOf(ptrs).alloced_memory),
        @as(f32, @TypeOf(ptrs).alloced_memory) /
            @as(f32, @TypeOf(ptrs).MAXSIZE));

    // Draw fst frame
    ptrs.redraw.* = true;

    ptrs.cursor_pos[0] = 1;
    ptrs.cursor_pos[1] = 1;
    { // map initialization
        const t = info.Map_Tile;
        ptrs.map.* = [map_size_y][map_size_x]t{
[_]t{.woods} ++ [_]t{.plains}**8 ++ [_]t{.mountain}**2 ++ [_]t{.plains}**4,
[_]t{.plains, .woods, .plains, .plains, .city, .city, .plains, .woods, .plains} ++ [_]t{.mountain}**2 ++ [_]t{.plains}**2 ++ [_]t{.road, .hq},
[_]t{.plains} ++ [_]t{.road}**7 ++ [_]t{.woods} ++ [_]t{.mountain}**2 ++ [_]t{.city, .plains, .road, .plains},
[_]t{.plains, .road} ++ [_]t{.plains}**2 ++ [_]t{.mountain}**2 ++ [_]t{.plains, .road, .plains} ++ [_]t{.mountain}**2 ++ [_]t{.plains, .plains, .road, .plains},
[_]t{.plains, .road} ++ [_]t{.plains}**2 ++ [_]t{.mountain}**2 ++ [_]t{.plains, .road, .plains} ++ [_]t{.mountain}**2 ++ [_]t{.plains, .plains, .road, .plains},
[_]t{.river, .bridge} ++ [_]t{.river}**5 ++ [_]t{.bridge} ++ [_]t{.river}**5 ++ [_]t{.bridge, .river},
[_]t{.plains, .road} ++ [_]t{.plains}**2 ++ [_]t{.mountain}**2 ++ [_]t{.plains, .road, .plains} ++ [_]t{.mountain}**2 ++ [_]t{.plains, .plains, .road, .plains},
[_]t{.plains, .road} ++ [_]t{.plains}**2 ++ [_]t{.mountain}**2 ++ [_]t{.plains} ++ [_]t{.road}**7 ++ [_]t{.plains},
[_]t{.hq, .road, .plains, .city} ++ [_]t{.mountain}**2 ++ [_]t{.woods} ++ [_]t{.plains}**6 ++ [_]t{.woods, .plains},
[_]t{.plains, .road, .plains, .plains} ++ [_]t{.mountain}**2 ++ [_]t{.plains, .woods, .plains, .city, .city, .plains, .plains, .plains, .woods},
        };
        // ptrs.map[7][8] = .mountain;
        // var i: u8 = 0;
        // var j: u8 = 0;
        // while ( j < map_size_y ) : ( j += 1 ) {
        //     i = 0;
        //     while ( i < map_size_x ) : ( i += 1 ) {
        //         if ( i == 0 or i == map_size_x-1 or j == 0 or j == map_size_y-1 ) {
        //             ptrs.map[j][i] = .mountain;
        //         }
        //     }
        // }
    }
    { // Set team count
        ptrs.team_num.* = 2;
    }
    { // obj_map inicialization
        ptrs.obj_map.* = .{ .{ null } ** map_size_x } ** map_size_y;
    }
    { // Put objs
        const team_num = ptrs.team_num.*;
        var i: u7 = 0;
        var j: u8 = 0;
        while ( j < 20 ) : ( j += 1 ) {
            const x = (j * 0x5) % (map_size_x - 2) + 1;
            const y = (j * 0x3) % (map_size_y - 2) + 1;
            if ( x == 0 or x == map_size_x-1 or y == 0 or y == map_size_y-1 ) {
            } else {
                const obj_id = @intToEnum(info.Unity_Id, i % info.Unity_Id.cnt);
                const team = @intCast(u2, i % team_num);
                const num = obj.create(obj_id, team, x, y);
                ptrs.obj_info[num].acted = false;
                i += 1;
            }
        }
    }

    w4.SYSTEM_FLAGS.* = w4.SYSTEM_PRESERVE_FRAMEBUFFER;

    // w4.tone(10, 60, 100, 0);
    w4.tone(262 | (253 << 16), 60, 30, w4.TONE_PULSE1 | w4.TONE_MODE3);
}

export fn update() void {
    const timer = &ptrs.gpads_timer[0];
    const gpads = ptrs.gpads;
    const cam = ptrs.cam;
    const cursor_pos = ptrs.cursor_pos;

    // Input handling
    const pad_old = gpads[0];
    const pad_new = w4.GAMEPAD1.*;
    const pad_diff = pad_old ^ pad_new;

    if ( cursor_pos[1] < map_size_y - 1
        and (pad_diff & w4.BUTTON_DOWN == w4.BUTTON_DOWN or timer[0] == 0)
        and pad_new & w4.BUTTON_DOWN == w4.BUTTON_DOWN ) {
        timer[0] = gpad_timer_max;
        ptrs.redraw.* = true;
        switch ( ptrs.cursor_state.* ) {
            .initial, .selected => {
                cursor_pos[1] += 1;
            },
            .moved, .day_menu => ptrs.cursor_menu.inc(),
            .unload_menu => ptrs.unloaded_menu.inc(),
            .unload => {
                ptrs.unloaded.inc();
                const i = ptrs.unloaded.*.i;
                ptrs.cursor_pos.* = ptrs.unloaded_buff[i];
            },
            .attack => {
                const i = ptrs.attacked.*.i;
                const max = ptrs.attacked.*.max;
                const atk = ( i + 1 ) % max;
                const num = ptrs.attac_buff[atk];
                ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                ptrs.attacked.*.i = atk;
            },
        }
    } else if ( cursor_pos[1] > 0
        and (pad_diff & w4.BUTTON_UP == w4.BUTTON_UP or timer[1] == 0)
        and pad_new & w4.BUTTON_UP == w4.BUTTON_UP ) {
        timer[1] = gpad_timer_max;
        ptrs.redraw.* = true;
        switch ( ptrs.cursor_state.* ) {
            .initial, .selected => {
                cursor_pos[1] -= 1;
            },
            .moved, .day_menu => ptrs.cursor_menu.dec(),
            .unload_menu => ptrs.cursor_menu.dec(),
            .unload => {
                ptrs.unloaded.dec();
                const i = ptrs.unloaded.*.i;
                ptrs.cursor_pos.* = ptrs.unloaded_buff[i];
            },
            .attack => {
                const i = ptrs.attacked.*.i;
                const max = ptrs.attacked.*.max;
                const atk = ( i -% 1 +% max ) % max;
                const num = ptrs.attac_buff[atk];
                ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                ptrs.attacked.*.i = atk;
            },
        }
    }

    if ( cursor_pos[0] < map_size_x - 1
        and (pad_diff & w4.BUTTON_RIGHT == w4.BUTTON_RIGHT or timer[2] == 0)
        and pad_new & w4.BUTTON_RIGHT == w4.BUTTON_RIGHT ) {
        timer[2] = gpad_timer_max;
        ptrs.redraw.* = true;
        switch ( ptrs.cursor_state.* ) {
            .initial, .selected => {
                cursor_pos[0] += 1;
            },
            .moved, .unload_menu, .day_menu => {},
            .unload => {
                ptrs.unloaded.inc();
                const i = ptrs.unloaded.*.i;
                ptrs.cursor_pos.* = ptrs.unloaded_buff[i];
            },
            .attack => {
                const i = ptrs.attacked.*.i;
                const max = ptrs.attacked.*.max;
                const atk = ( i + 1 ) % max;
                const num = ptrs.attac_buff[atk];
                ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                ptrs.attacked.*.i = atk;
            },
        }
    } else if ( cursor_pos[0] > 0
        and (pad_diff & w4.BUTTON_LEFT == w4.BUTTON_LEFT or timer[3] == 0)
        and pad_new & w4.BUTTON_LEFT == w4.BUTTON_LEFT ) {
        timer[3] = gpad_timer_max;
        ptrs.redraw.* = true;
        switch ( ptrs.cursor_state.* ) {
            .initial, .selected => {
                cursor_pos[0] -= 1;
            },
            .moved, .unload_menu, .day_menu => {},
            .unload => {
                ptrs.unloaded.dec();
                const i = ptrs.unloaded.*.i;
                ptrs.cursor_pos.* = ptrs.unloaded_buff[i];
            },
            .attack => {
                ptrs.attacked.dec();
                const atk = ptrs.attacked.*.i;
                const num = ptrs.attac_buff[atk];
                ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
            },
        }
    }

    if ( pad_diff & w4.BUTTON_1 == w4.BUTTON_1
            and pad_new & w4.BUTTON_1 == w4.BUTTON_1 ) {
        ptrs.redraw.* = true;
        switch ( ptrs.cursor_state.* ) {
            .initial => {
                const n: ?ObjId = get_obj_num_on_cursor();

                if ( n != null and !ptrs.obj_info[n.?].acted ) {
                    const num = n.?;
                    calculate_movable_tiles(num);

                    ptrs.cursor_state.* = .selected;
                } else {
                    ptrs.cursor_menu.* = .{ .i = 0, .max = day_menu.size };
                    ptrs.cursor_state.* = .day_menu;
                }
            },
            .selected => {
                ptrs.moved_contex.* = .{};
                var menu_max: u4 = 0;
                const num = ptrs.selec_obj.*;
                const this_obj_info = &ptrs.obj_info[num];
                const team = this_obj_info.team;
                const offset = ptrs.selec_offset;
                const old_x = ptrs.obj_pos[0][num];
                const old_y = ptrs.obj_pos[1][num];
                const new_x = ptrs.cursor_pos[0];
                const new_y = ptrs.cursor_pos[1];
                const old_selec_x = new_x -% offset[0];
                const old_selec_y = new_y -% offset[1];
                if ( team == ptrs.curr_team.*
                    and old_selec_x < selected_range
                    and old_selec_y < selected_range
                    and ptrs.selected[old_selec_y][old_selec_x] != null
                    ) {
                    const id = ptrs.obj_id[num];
                    const may_unload =
                        this_obj_info.transporting != null
                        and ptrs.map[new_y][new_x].move_cost(
                            ptrs.obj_id[this_obj_info.transporting.?]
                            .move_cost().typ ) != null;
                    const is_empty = ptrs.obj_map[new_y][new_x] == null
                        or ptrs.obj_map[new_y][new_x].? == num;
                    const should_join =
                        if ( ptrs.obj_map[new_y][new_x] ) |n2|
                            if ( num != n2
                                and id == ptrs.obj_id[n2]
                                and (this_obj_info.*.health < max_health
                                    or ptrs.obj_info[n2].health < max_health)
                            ) true else false
                        else false;
                    const should_load =
                        if ( ptrs.obj_map[new_y][new_x] ) |n2|
                            if ( num != n2
                                and ptrs.obj_id[n2].may_transport(id)
                            ) true else false
                        else false;
                    if ( may_unload and is_empty) {
                        const n2 = this_obj_info.transporting.?;
                        const move_typ = ptrs.obj_id[n2].move_cost().typ;

                        const center = (selected_range - 1) / 2;
                        offset.*[0] = new_x -% center;
                        offset.*[1] = new_y -% center;
                        ptrs.selected.* =
                            .{ .{ null } ** selected_range }
                                ** selected_range;
                        var i: u4 = 0;
                        const directions = [4][2]u8{
                            .{ new_x, new_y-%1 }, .{ new_x-%1, new_y },
                            .{ new_x+1, new_y }, .{ new_x, new_y+1 }
                        };
                        for ( directions ) |d| {
                            const dx = d[0];
                            const dy = d[1];
                            const sx = dx -% offset[0];
                            const sy = dy -% offset[1];
                            const tile = ptrs.map[dy][dx];
                            if ( dx < map_size_x
                                and dy < map_size_y
                                and ptrs.obj_map[dy][dx] == null
                                and tile.move_cost(move_typ)
                                    != null ) {
                                ptrs.selected[sy][sx] = 1;
                                ptrs.unloaded_buff[i] = .{ dx, dy };
                                i += 1;
                            }
                        }
                        if ( i > 0 ) {
                            ptrs.unloaded.* = .{ .i = 0, .max = i };
                            menu_max += 1;
                            ptrs.moved_contex.*.unload = true;
                        }
                    }
                    if ( id == .apc and is_empty ) {
                        obj.moveTo(num, new_x, new_y);
                        const directions = [4][2]u8{
                            .{ new_x, new_y-%1 }, .{ new_x-%1, new_y },
                            .{ new_x+1, new_y }, .{ new_x, new_y+1 }
                        };
                        for ( directions ) |d| {
                            const dx = d[0];
                            const dy = d[1];
                            if ( dx < map_size_x
                                and dy < map_size_y
                                and ptrs.obj_map[dy][dx] != null ) {
                                const n2 = ptrs.obj_map[dy][dx].?;
                                if ( team == ptrs.obj_info[n2].team ) {
                                    menu_max += 1;
                                    ptrs.moved_contex.*.supply = true;
                                }
                            }
                        }
                        menu_max += 1;
                        ptrs.moved_contex.*.wait = true;
                        ptrs.cursor_menu.* = .{ .i = 0, .max = menu_max };
                        ptrs.cursor_state.* = .moved;
                    } else if ( should_join ) {
                        ptrs.obj_map[old_y][old_x] = null;
                        menu_max += 1;
                        ptrs.moved_contex.*.join = true;
                        ptrs.cursor_menu.* = .{ .i = 0, .max = menu_max };
                        ptrs.cursor_state.* = .moved;
                    } else if ( should_load ) {
                        ptrs.obj_map[old_y][old_x] = null;
                        menu_max += 1;
                        ptrs.moved_contex.*.load = true;
                        ptrs.cursor_menu.* = .{ .i = 0, .max = menu_max };
                        ptrs.cursor_state.* = .moved;
                    } else if ( is_empty ) {
                        obj.moveTo(num, new_x, new_y);

                        const center = (selected_range - 1) / 2;
                        offset.*[0] = new_x -% center;
                        offset.*[1] = new_y -% center;
                        ptrs.selected.* =
                            .{ .{ null } ** selected_range }
                                ** selected_range;
                        var i: u4 = 0;
                        const directions = [4][2]u8{
                            .{ new_x, new_y-%1 }, .{ new_x-%1, new_y },
                            .{ new_x+1, new_y }, .{ new_x, new_y+1 }
                        };
                        for ( directions ) |d| {
                            const dx = d[0];
                            const dy = d[1];
                            const sx = dx -% offset[0];
                            const sy = dy -% offset[1];
                            if ( dx < map_size_x
                                and dy < map_size_y
                                and ptrs.obj_map[dy][dx] != null ) {
                                const n2 = ptrs.obj_map[dy][dx].?;
                                const id2 = ptrs.obj_id[n2];
                                if ( team != ptrs.obj_info[n2].team
                                    and id.attack(id2) != null ) {
                                    ptrs.selected[sy][sx] = 1;
                                    ptrs.attac_buff[i] = n2;
                                    i += 1;
                                }
                            }
                        }
                        if ( i > 0 ) {
                            ptrs.attacked.* = .{ .i = 0, .max = i };
                            menu_max += 1;
                            ptrs.moved_contex.*.fire = true;
                        }
                        menu_max += 1;
                        ptrs.moved_contex.*.wait = true;
                        ptrs.cursor_menu.* = .{ .i = 0, .max = menu_max };
                        ptrs.cursor_state.* = .moved;
                    }
                }
            },
            .moved => {
                const ctx = ptrs.moved_contex;
                var cnt: u4 = ptrs.cursor_menu.*.i;
                const fields = @typeInfo(Moved_Contex).Struct.fields;
                const chosen = inline for ( fields ) |f, i| {
                    if ( @field(ctx, f.name) ) {
                        if ( cnt == 0 )
                            break @intToEnum(MvdCtxEnum(), i);
                        cnt -= 1;
                    }
                };
                switch ( chosen ) {
                    .@"capture", => {
                        w4.trace("capture: not implemented");
                        unreachable;
                    },
                    .@"no fire", => {
                        w4.trace("no fire: \"not\" implemented");
                        w4.trace("(Yes, it should actually do nothing!)");
                    },
                    .@"fire",    => {
                        const num = ptrs.attac_buff[0];
                        ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                        ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                        ptrs.cursor_state.* = .attack;
                    },
                    .@"unload",  => {
                        ptrs.unloaded_menu.* = .{ .i = 0, .max = 1 };
                        ptrs.cursor_state.* = .unload_menu;
                    },
                    .@"supply",  => {
                        const num = ptrs.selec_obj.*;
                        const x = ptrs.obj_pos[0][num];
                        const y = ptrs.obj_pos[1][num];
                        const team = ptrs.obj_info[num].team;
                        const directions = [4][2]u8{
                            .{ x, y-%1 }, .{ x-%1, y },
                            .{ x+1, y }, .{ x, y+1 }
                        };
                        for ( directions ) |d| {
                            const dx = d[0];
                            const dy = d[1];
                            if ( dx < map_size_x
                                and dy < map_size_y
                                and ptrs.obj_map[dy][dx] != null ) {
                                const n2 = ptrs.obj_map[dy][dx].?;
                                if ( team == ptrs.obj_info[n2].team ) {
                                    obj.supply(n2);
                                }
                            }
                        }
                        ptrs.obj_info[num].acted = true;
                        ptrs.cursor_state.* = .initial;
                    },
                    .@"join",  => {
                        const num = ptrs.selec_obj.*;
                        const id = ptrs.obj_id[num];
                        const x = ptrs.cursor_pos[0];
                        const y = ptrs.cursor_pos[1];
                        const n2 = ptrs.obj_map[y][x].?;
                        obj.join(n2, num, id);
                        ptrs.cursor_state.* = .initial;
                    },
                    .@"load",  => {
                        const num = ptrs.selec_obj.*;
                        const x = ptrs.cursor_pos[0];
                        const y = ptrs.cursor_pos[1];
                        const n2 = ptrs.obj_map[y][x].?;
                        ptrs.obj_info[n2].transporting = num;
                        ptrs.obj_info[num].acted = true;
                        ptrs.cursor_state.* = .initial;
                    },
                    .@"wait",    => {
                        const num = ptrs.selec_obj.*;
                        ptrs.obj_info[num].acted = true;
                        ptrs.cursor_state.* = .initial;
                    },
                }
            },
            .unload_menu => {
                const i = ptrs.unloaded.*.i;
                ptrs.cursor_pos.* = ptrs.unloaded_buff[i];
                ptrs.cursor_state.* = .unload;
            },
            .unload => {
                const num = ptrs.selec_obj.*;
                const n2 = ptrs.obj_info[num].transporting.?;
                const n2_x = ptrs.cursor_pos[0];
                const n2_y = ptrs.cursor_pos[1];
                obj.moveTo(n2, n2_x, n2_y);
                ptrs.obj_info[num].acted = true;
                ptrs.obj_info[n2].acted = true;
                ptrs.cursor_state.* = .initial;
            },
            .attack => {
                const atk_num = ptrs.selec_obj.*;
                const def_num = ptrs.attac_buff[ptrs.attacked.*.i];
                obj.attack(atk_num, def_num);
                ptrs.cursor_state.* = .initial;
            },
            .day_menu => switch ( day_menu.name(ptrs.cursor_menu.*.i) ) {
                .@"Cancel"  => ptrs.cursor_state.* = .initial,
                .@"End Day" => {
                    const curr_team = ptrs.curr_team.*;

                    reset_acted(curr_team);
                    const next_team = (curr_team + 1) % ptrs.team_num.*;
                    ptrs.curr_team.* = next_team;
                    if ( next_team < curr_team ) {
                        ptrs.curr_day.* += 1;
                    }

                    turn_start(next_team);
                    ptrs.cursor_state.* = .initial;
                },
            },
        }
    } else if ( pad_diff & w4.BUTTON_2 == w4.BUTTON_2
            and pad_new & w4.BUTTON_2 == w4.BUTTON_2 ) {
        ptrs.redraw.* = true;
        switch ( ptrs.cursor_state.* ) {
            .initial => {},
            .selected => ptrs.cursor_state.* = .initial,
            .moved => {
                const num = ptrs.selec_obj.*;
                const old_x = ptrs.selec_pos[0];
                const old_y = ptrs.selec_pos[1];

                obj.moveTo(num, old_x, old_y);
                ptrs.cursor_pos.* = .{ old_x, old_y };

                calculate_movable_tiles(num);

                ptrs.cursor_state.* = .selected;
            },
            .unload_menu => ptrs.cursor_state.* = .moved,
            .unload => ptrs.cursor_state.* = .unload_menu,
            .attack => ptrs.cursor_state.* = .moved,
            .day_menu => ptrs.cursor_state.* = .initial,
        }
    }

    // Camera movement
    const cam_max_x = map_size_x - screen_tiles_x;
    const xdiff = @intCast(i8, cursor_pos[0]) - @intCast(i8, cam[0]);
    if ( 0 <= cam[0] and cam[0] < cam_max_x and xdiff > screen_tiles_x - 2 ) {
        cam[0] += 1;
    } else if ( 0 < cam[0] and cam[0] <= cam_max_x and xdiff < 2 ) {
        cam[0] -= 1;
    }
    const cam_max_y = map_size_y - screen_tiles_y;
    const ydiff = @intCast(i8, cursor_pos[1]) - @intCast(i8, cam[1]);
    if ( 0 <= cam[1] and cam[1] < cam_max_y and ydiff > screen_tiles_y - 2 ) {
        cam[1] += 1;
    } else if ( 0 < cam[1] and cam[1] <= cam_max_y and ydiff < 2 ) {
        cam[1] -= 1;
    }

    gpads[0] = pad_new;
    for (timer) |*t| if ( t.* > 0 ) { t.* -= 1; };

    if ( ptrs.redraw.* ) {
        draw();
        ptrs.redraw.* = false;
    }
}

fn get_obj_num_on_cursor() ?ObjId {
    const c_p = ptrs.cursor_pos;
    return ptrs.obj_map[c_p[1]][c_p[0]];
}

fn calculate_movable_tiles(num: ObjId) void {
    const obj_info = ptrs.obj_info[num];
    const team = obj_info.team;
    const id = ptrs.obj_id[num];

    const fuel = obj_info.fuel;
    const move_cost = id.move_cost();
    const mv_typ = move_cost.typ;
    const mv_max = move_cost.moves;

    const gas = if ( mv_max < fuel )
        mv_max else @intCast(u4, fuel);

    const center = (selected_range - 1) / 2;
    const selec_x = ptrs.cursor_pos[0] -% center;
    const selec_y = ptrs.cursor_pos[1] -% center;
    ptrs.selec_offset[0] = selec_x;
    ptrs.selec_offset[1] = selec_y;
    ptrs.selec_obj.* = num;
    ptrs.selec_pos.* = ptrs.cursor_pos.*;

    // Flood fill (DFS)
    var len: u8 = 1;
    const q_size = 0x30;
    var queue: [q_size][2]u8 = .{ .{ 0, 0 } } ** q_size;
    var local_selec: [selected_range][selected_range]?info.Cost =
        .{ .{ null } ** selected_range } ** selected_range;
    queue[0] = .{ center, center };
    local_selec[center][center] = gas;

    while ( len > 0 ) {
        len -= 1;
        const x = queue[len][0];
        const y = queue[len][1];
        if ( local_selec[y][x] ) |rem_fuel| {
            const directions = [4][2]u8{
                .{ x, y-%1 }, .{ x-%1, y }, .{ x+1, y }, .{ x, y+1 }
            };
            for ( directions ) |d| {
                const dx = d[0];
                const dy = d[1];
                if ( dx >= selected_range or dy >= selected_range ) {
                    w4.trace("Flood fill: unit has too much movement?");
                    unreachable;
                }
                const sx = dx +% selec_x;
                const sy = dy +% selec_y;
                if ( sx >= map_size_x or sy >= map_size_y ) continue;
                const movable = ptrs.map[sy][sx].move_cost(mv_typ);
                if ( movable ) |cost| {
                    const maybe_same_team =
                        if ( ptrs.obj_map[sy][sx] ) |n2|
                            team == ptrs.obj_info[n2].team
                        else null;
                    var new_fuel: info.Cost = undefined;
                    const overflow = @subWithOverflow(info.Cost,
                        rem_fuel, cost, &new_fuel);
                    if ( !overflow
                            and ( maybe_same_team == null or
                                maybe_same_team.? )
                        and ( local_selec[dy][dx] == null
                            or local_selec[dy][dx].? < new_fuel ) ) {
                        local_selec[dy][dx] = new_fuel;
                        if ( len == q_size ) {
                            w4.trace("Flood fill: queue overflow!");
                            unreachable;
                        }
                        queue[len] = .{ dx, dy };
                        len = len + 1;
                    }
                }
            }
        } else {
            w4.tracef("Flood Fill: found null value at pos (%d, %d)",
                x, y);
            w4.tracef("id: %d, move_max: %d", id, mv_max);
            w4.tracef("fuel: %d, gas: %d", fuel, gas);
            w4.tracef("len: %d", len);
            w4.trace("queue:");
            for (queue) |q, i| {
                w4.tracef("  %d: (%d, %d)", i, q[0], q[1]);
            }
            unreachable;
        }
    }
    ptrs.selected.* = local_selec;

    // note: Useful for ranged attacks
    // for ( ptrs.selected ) |*ss, jj| {
    //     const j = @intCast(u8, jj);
    //         if ( y +% j >= map_size_y ) continue;
    //     const dj = if ( j < center )
    //         center - j else j - center;
    //     for (ss) |*s, ii| {
    //         const i = @intCast(u8, ii);
    //         if ( x +% i >= map_size_x ) continue;
    //         const di = if ( i < center )
    //             center - i else i - center;
    //         const empty_space = ptrs.obj_map[y+%j][x+%i] == null;
    //         const no_move = di + dj == 0;
    //         if ( di + dj <= range and (empty_space or no_move) ) {
    //             s.* = 1;
    //         } else {
    //             s.* = 0;
    //         }
    //     }
    // }
}

fn reset_acted(team: Team) void {
    for ( ptrs.obj_info.* ) |*obj_info| {
        if ( obj_info.*.team == team ) {
            obj_info.*.acted = false;
        }
    }
}

fn turn_start(team: Team) void {
    _ = team;
}

fn draw() void {
    draw_map();

    draw_objs();

    draw_cursor();
}

fn draw_map() void {
    const cx: u8 = ptrs.cam[0];
    const cy: u8 = ptrs.cam[1];

    const ts = tilespace;
    const map = ptrs.map;

    var i: u8 = 0;
    var j: u8 = 0;
    while ( j < screen_tiles_y ) : ( j += 1 ) {
        const y = cy +% j;
        const yts = @as(i32, y) * @as(i32, ts);
        if ( y >= map_size_y ) continue;
        i = 0;
        w4.DRAW_COLORS.* = 0x43;
        while ( i < screen_tiles_x ) : ( i += 1 ) {
            const x = cx +% i;
            const xts = @as(i32, x) * @as(i32, ts);
            if ( x >= map_size_x ) continue;
            const tile = map[y][x];
            switch (tile) {
                .plains => {
                    w4.DRAW_COLORS.* = 0x42;
                    blit4(&g.square, xts, yts, 8, 8, 0);
                },
                .woods => {
                    w4.DRAW_COLORS.* = 0x42;
                    blit(&g.woods, xts, yts, 16, 16, 0);
                },
                .mountain => {
                    w4.DRAW_COLORS.* = 0x42;
                    blit(&g.mountain, xts, yts, 16, 16, 0);
                },
                .road, .bridge => {
                    w4.DRAW_COLORS.* = 0x04;
                    blit4(&g.square, xts, yts, 8, 8, 0);

                    w4.DRAW_COLORS.* = 0x42;
                    blit(&g.road_pc, xts + 4, yts    , 4, 8, 0);
                    blit(&g.road_pc, xts + 8, yts    , 4, 8, 2);
                    blit(&g.road_pc, xts + 4, yts + 8, 4, 8, 0);
                    blit(&g.road_pc, xts + 8, yts + 8, 4, 8, 2);

                    // blit(&g.road_pc_rot, xts    , yts + 4, 8, 4, 0);
                    // blit(&g.road_pc_rot, xts + 8, yts + 4, 8, 4, 0);
                    // blit(&g.road_pc_rot, xts    , yts + 8, 8, 4, 4);
                    // blit(&g.road_pc_rot, xts + 8, yts + 8, 8, 4, 4);
                },
                .river => {
                    w4.DRAW_COLORS.* = 0x42;
                    blit(&g.river, xts, yts, 16, 16, 0);
                },
                .sea => {
                    w4.DRAW_COLORS.* = 0x44;
                    blit4(&g.square, xts, yts, 8, 8, 0);
                },
                else => {
                    w4.DRAW_COLORS.* = 0x21;
                    blit4(&g.sqr_border_q, xts, yts, 8, 8, 0);
                }
            }
        }
    }

    switch (ptrs.cursor_state.*) {
        .initial, .moved, .unload_menu, .day_menu => {},
        .selected, .unload, .attack => {
            const sx = ptrs.selec_offset[0];
            const sy = ptrs.selec_offset[1];
            for ( ptrs.selected ) |line, jj| {
                const sj = @intCast(u8, jj);
                const y = sy +% sj;
                const yts = @as(i32, y) * ts;
                if ( y >= map_size_y ) continue;
                for ( line ) |p, ii| {
                    const si = @intCast(u8, ii);
                    const x = sx +% si;
                    const xts = @as(i32, x) * ts;
                    if ( x >= map_size_x ) continue;
                    if ( p ) |_| {
                        w4.DRAW_COLORS.* = 0x01;
                        blit4(&g.sqr_selected_q, xts, yts, 8, 8, 0);
                    }
                }
            }
        },
    }
}

fn draw_cursor() void {
    const x = @as(i32, ptrs.cursor_pos[0]) * tilespace;
    const y = @as(i32, ptrs.cursor_pos[1]) * tilespace;
    w4.DRAW_COLORS.* = 0x03;

    const state = ptrs.cursor_state.*;
    switch ( state ) {
        .initial, .selected, .unload =>
            blit4(&g.select_q, x, y, 8, 8, 0),
        .moved, .unload_menu => draw_menu(state),
        .attack => blit4(&g.select_q, x, y, 8, 8, 4),
        .day_menu => day_menu.draw(),
    }
}

fn draw_menu(state: Cursor_State) void {
    const x = @as(i32, ptrs.cursor_pos[0]) * tilespace;
    const y = @as(i32, ptrs.cursor_pos[1]) * tilespace;

    const xa = x + tilespace;
    const ya = y + 8 * ptrs.cursor_menu.*.i;
    const off = 2;

    const ctx = ptrs.moved_contex.*;

    const block_cnt = switch ( state ) {
        .initial, .selected, .unload, .attack, .day_menu, => {
            w4.trace("draw_menu: receaved unreachable state");
            unreachable;
        },
        .moved => blk: {
            const fields = @typeInfo(Moved_Contex).Struct.fields;
            comptime var max_len = 0;
            comptime var texts: [fields.len][]const u8 = undefined;
            inline for ( fields ) |f, i| {
                texts[i] = f.name;
                if ( f.name.len > max_len ) max_len = f.name.len;
            }

            const size = ptrs.cursor_menu.*.max;
            const block_cnt = max_len / 2 + 1;

            draw_menu_back(xa, y, size, block_cnt);
            w4.DRAW_COLORS.* = 0x02;
            var i: u8 = 0;
            inline for ( texts ) |t| {
                if ( @field(ctx, t) ) {
                    text(t, xa + off, y + off + @intCast(i32, i) * 8);
                    i += 1;
                }
            }

            break :blk block_cnt;
        },
        .unload_menu => blk: {
            const num = ptrs.selec_obj.*;
            const n2 = ptrs.obj_info[num].transporting.?;
            const id = ptrs.obj_id[n2];

            const size = ptrs.unloaded_menu.*.max;

            const name_len = @intCast(u8, id.name_len());
            const block_cnt = name_len / 2 + 1;

            draw_menu_back(xa, y, size, block_cnt);

            w4.DRAW_COLORS.* = 0x02;
            switch ( id ) {
                .infantry => text("infantry", xa + off, y + off),
                .mech     => text("mech"    , xa + off, y + off),
                .apc      => text("apc"     , xa + off, y + off),
            }

            break :blk block_cnt;
        },
    };

    w4.DRAW_COLORS.* = 0x03;
    blit(&g.select_thin_q, xa, ya, 8, 8, 0);
    blit(&g.select_thin_q, xa + 8 * (block_cnt - 1), ya, 8, 8, 6);
}

fn draw_menu_back(xa: i32, y: i32, size: u8, block_cnt: u8) void {
    w4.DRAW_COLORS.* = 0x01;
    var j: u8 = 0;
    while ( j < size ) : ( j += 1 ) {
        var i: u8 = 0;
        while ( i < block_cnt ) : ( i += 1 ) {
            blit(&g.square, xa + i * 8, y + j * 8, 8, 8, 0);
        }
    }
}

fn draw_objs() void {
    const cx = ptrs.cam[0];
    const cy = ptrs.cam[1];
    var j: u7 = 0;
    var i: u7 = 0;
    while ( j < screen_tiles_y ) : ( j += 1 ) {
        i = 0;
        while ( i < screen_tiles_x ) : ( i += 1 ) {
            if ( ptrs.obj_map[cy+j][cx+i] ) |num| {
                const id = ptrs.obj_id[num];
                const x = @as(i32, cx+i) * tilespace + 4;
                const y = @as(i32, cy+j) * tilespace + 4;
                const obj_info = ptrs.obj_info[num];

                // Health Bar
                const health = obj_info.health / 10 + 1;
                w4.DRAW_COLORS.* = 0x0004;
                if ( health <= 10 ) {
                    rect(x - 1, y - 1, health, 1);
                    if ( health > 6 ) {
                        w4.DRAW_COLORS.* = 0x0003;
                        rect(x - 1 + 4, y - 1, 2, 1);
                    } else if ( health == 5 ) {
                        w4.DRAW_COLORS.* = 0x0003;
                        rect(x - 1 + 4, y - 1, 1, 1);
                    }
                }

                const color: u16 = switch (obj_info.team) {
                    0 => 0x0133,
                    1 => 0x0144,
                    2 => 0x0143,
                    3 => 0x0123,
                };
                if ( ptrs.obj_info[num].acted ) {
                    w4.DRAW_COLORS.* = color & 0xF0FF | 0x0200;
                } else {
                    w4.DRAW_COLORS.* = color;
                }

                switch (id) {
                    .infantry => blit(&g.infantry, x, y, 8, 8, 1),
                    .mech     => blit(&g.mech    , x, y, 8, 8, 1),
                    .apc      => blit(&g.apc     , x, y, 8, 8, 1),
                }

                if ( obj_info.transporting != null ) {
                    w4.DRAW_COLORS.* = 0x01;
                    blit(&g.square, x + 4, y + 4, 3, 3, 0);
                }
            }
        }
    }

}

fn rect(x: i32, y: i32, width: u32, height: u32) void {
    w4.rect(x - @as(i32, ptrs.cam[0]) * tilespace,
            y - @as(i32, ptrs.cam[1]) * tilespace,
            width, height);
}

fn blit(sprite: [*]const u8, x: i32, y: i32,
    width: i32, height: i32, flags: u32) void {
    w4.blit(sprite,
        x - @as(i32, ptrs.cam[0]) * tilespace,
        y - @as(i32, ptrs.cam[1]) * tilespace,
        width, height, flags);
}

fn blit4(sprite: [*]const u8, x: i32, y: i32,
    w: i32, h: i32, flags: u32) void {
    blit(sprite, x    , y    , w, h, flags ^ 0);
    blit(sprite, x + w, y    , w, h, flags ^ 2);
    blit(sprite, x    , y + h, w, h, flags ^ 4);
    blit(sprite, x + w, y + h, w, h, flags ^ 6);
}

fn text(comptime str: []const u8, x: i32, y: i32) void {
    const letters = alphabet.encode(str);
    const advance = 4;
    for (letters) |l, i| {
        if (l) |letter| {
            blit(&letter, x + @intCast(i32, i) * advance, y, 8, 4, 0);
        }
    }
}

const ST = ?*@import("std").builtin.StackTrace;
pub fn panic(msg: []const u8, trace: ST) noreturn {
    @setCold(true);

    w4.trace(">> ahh, panic!");
    w4.trace(msg);
    if ( trace ) |t| {
        w4.tracef("  index: %d", @intCast(i32, t.index));
    } else {
        w4.trace("  no trace :(");
    }

    while ( true ) {
        @breakpoint();
    }
}
