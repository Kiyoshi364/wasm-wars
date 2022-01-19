const assert = @import("std").debug.assert;

const w4 = @import("wasm4.zig");

const g = @import("graphics.zig");
const info = @import("simple_info.zig");

// Input
const gpad_timer_max = 13;

// Map
const tilespace = 16;
const map_size_x = 10;
const map_size_y = map_size_x;
const screen_tiles_x = 10;
const screen_tiles_y =
    if (screen_tiles_x < map_size_y) screen_tiles_x else map_size_y;

// Objs / Things
const obj_cnt = 16;

// selection
const selected_range = 7;

const ptrs = struct {
    gpads: *[4]u8,
    gpads_timer: *[4][4]u4,

    redraw: *bool,

    map: *[map_size_y][map_size_x]info.Map_Tile,
    cam: *[2]u8,

    cursor_pos: *[2]u8,
    cursor_state: *Cursor_State,

    selec_offset: *[2]u8,
    selected: *[selected_range][selected_range]u1,
    selec_obj: *ObjId,
    selec_pos: *[2]u8,

    attacked: *u4,
    attac_buff: *[5:null]?ObjId,

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

const Cursor_State = enum(u8) {
    initial = 0,
    selected,
    attack,
    menu,
};

const ObjInfo = struct {
    acted: bool,
    health: u7,
    team: u2,
};

const ObjId = u7;

const obj = struct {

    pub fn create(id: info.Unity_Id, obj_info: ObjInfo, x: u8, y: u8) ObjId {
        const num = blk: {
            const freed_cnt = ptrs.freed_cnt.*;
            if ( freed_cnt > 0 ) {
                const num = ptrs.freed_list[freed_cnt - 1];
                ptrs.freed_cnt.* = freed_cnt - 1;
                break :blk num;
            } else {
                const num = ptrs.next_obj.*;
                ptrs.next_obj.* += 1;
                break :blk num;
            }
        };
        ptrs.obj_id[num] = id;
        ptrs.obj_info[num] = obj_info;
        ptrs.obj_map[y][x] = num;
        ptrs.obj_pos[0][num] = x;
        ptrs.obj_pos[1][num] = y;
        return num;
    }

    pub fn delete(num: ObjId) void {
        const x = ptrs.obj_pos[0][num];
        const y = ptrs.obj_pos[1][num];
        ptrs.obj_map[y][x] = null;

        // free memory
        const freed_cnt = ptrs.freed_cnt.*;
        const list = ptrs.freed_list;
        const next_obj = ptrs.next_obj.*;

        if ( num == next_obj - 1 ) {
            var unfreed: u7 = 1;
            var i: u7 = 1;
            while ( i < freed_cnt ) : ( i += 1 ) {
                if ( list[i] == next_obj - unfreed ) {
                    list[unfreed - 1] = list[i];
                    unfreed += 1;
                } else if ( unfreed == 1 ) {
                    break;
                }
            }
            ptrs.next_obj.* -= unfreed;
        } else {
            var n = num;
            var i: u7 = 0;
            while ( i < freed_cnt ) : ( i += 1 ) {
                assert( list[i] != n );
                if ( list[i] < n ) {
                    const tmp = list[i];
                    list[i] = n;
                    n = tmp;
                }
            }
            list[i] = n;
            ptrs.freed_cnt.* = freed_cnt + 1;
        }
    }

    pub fn moveTo(num: ObjId, x: u8, y: u8) void {
        const oldx = ptrs.obj_pos[0][num];
        const oldy = ptrs.obj_pos[1][num];

        assert(ptrs.obj_map[y][x] == null or ptrs.obj_map[y][x].? == num);

        ptrs.obj_map[oldy][oldx] = null;
        ptrs.obj_map[y][x] = num;

        ptrs.obj_pos[0][num] = x;
        ptrs.obj_pos[1][num] = y;
    }

    pub fn calc_attack(atk_num: ObjId, def_num: ObjId) u7 {
        const atk_id = ptrs.obj_id[atk_num];
        const def_id = ptrs.obj_id[def_num];

        const atk_info = ptrs.obj_info[atk_num];
        const def_info = ptrs.obj_info[def_num];

        const atk_health = (atk_info.health / 10) * 10;
        const def_health = (def_info.health / 10) * 10;

        // TODO: Add co lookup
        const co_atk_bonus = 100;
        const co_def_bonus = 100;

        // TODO: Add luck calculation (0 ~ 9)
        const luck = 0;

        const base_damage =
            @as(u16, atk_id.attack(def_id)) * co_atk_bonus / 100 + luck;

        // TODO: Get defence!
        const defense = 1;

        const pre_def_damage = base_damage * atk_health / 100;

        const total_damage = pre_def_damage
            * (200 - co_def_bonus - defense * def_health / 10) / 100;

        assert(0 < total_damage and total_damage < 0x80);
        return @intCast(u7, total_damage);

        // Formula 1:
        // s, d := CO attack-buffs, defence-buffs
        // t := [(b*s/d)*(a*0.1)]
        // f := t - r*[(t*0.1)-(t*0.1*h)]
        //
        // Formula 2:
        // (b * co_a / 100 + l) * a_h/10 * (200 - co_d - d * d_h) / 100
    }

    pub fn attack(atk_num: ObjId, def_num: ObjId) void {
        const atk_info = &ptrs.obj_info[atk_num];
        const def_info = &ptrs.obj_info[def_num];

        const atk_damage = calc_attack(atk_num, def_num);

        var def_health: u7 = undefined;
        if ( !@subWithOverflow(u7, def_info.*.health, atk_damage,
                &def_health) ) {
            def_info.*.health = @intCast(u7, def_health);

            const def_damage = calc_attack(def_num, atk_num);

            var atk_health: u7 = undefined;
            if ( !@subWithOverflow(u7, atk_info.*.health, def_damage,
                    &atk_health) ) {
                atk_info.*.health = atk_health;
            } else {
                obj.delete(atk_num);
            }
        } else {
            obj.delete(def_num);
        }
    }
};

export fn start() void {
    // Debug allocated memory
    w4.tracef("Memory Usage:\n  Allocated:    %d\n  Free for use: %d",
        @as(i32, @TypeOf(ptrs).alloced_memory),
        @as(i32, @TypeOf(ptrs).MAXSIZE - @TypeOf(ptrs).alloced_memory));

    // Draw fst frame
    ptrs.redraw.* = true;

    ptrs.cursor_pos[0] = 1;
    ptrs.cursor_pos[1] = 1;
    { // map initialization
        ptrs.map[7][8] = .mountain;
        var i: u8 = 0;
        var j: u8 = 0;
        while ( j < map_size_y ) : ( j += 1 ) {
            i = 0;
            while ( i < map_size_x ) : ( i += 1 ) {
                if ( i == 0 or i == map_size_x-1 or j == 0 or j == map_size_y-1 ) {
                    ptrs.map[j][i] = .sea;
                }
            }
        }
    }
    { // obj_map inicialization
        ptrs.obj_map.* = .{ .{ null } ** map_size_x } ** map_size_y;
    }
    { // Put objs
        var i: u7 = 0;
        var j: u8 = 0;
        while ( j < obj_cnt ) : ( j += 1 ) {
            const x = (j * 0x5) % (map_size_x - 2) + 1;
            const y = (j * 0x3) % (map_size_y - 2) + 1;
            if ( x == 0 or x == map_size_x-1 or y == 0 or y == map_size_y-1 ) {
            } else {
                const obj_id = @intToEnum(info.Unity_Id, i % info.Unity_Id.cnt);
                const obj_info = .{
                    .acted = false,
                    .health = 100,
                    .team = @intCast(u2, i % 2),
                };
                _ = obj.create(obj_id, obj_info, x, y);
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
        switch (ptrs.cursor_state.*) {
            .initial, .selected => {
                cursor_pos[1] += 1;
            },
            .attack => {
                const atk = ptrs.attacked.* + 1;
                if ( ptrs.attac_buff[atk] ) |num| {
                    ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                    ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                    ptrs.attacked.* = atk;
                } else {
                    const num = ptrs.attac_buff[0].?;
                    ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                    ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                    ptrs.attacked.* = 0;
                }
            },
            .menu => {},
        }
    } else if ( cursor_pos[1] > 0
        and (pad_diff & w4.BUTTON_UP == w4.BUTTON_UP or timer[1] == 0)
        and pad_new & w4.BUTTON_UP == w4.BUTTON_UP ) {
        timer[1] = gpad_timer_max;
        ptrs.redraw.* = true;
        switch (ptrs.cursor_state.*) {
            .initial, .selected => {
                cursor_pos[1] -= 1;
            },
            .attack => {
                const last_atk = blk: {
                    var i: u4 = 1;
                    while ( ptrs.attac_buff[i] != null ) : ( i += 1 ) {}
                    break :blk i-1;
                };
                const atk = if (ptrs.attacked.* - 1 >= 0)
                    ptrs.attacked.* - 1 else last_atk;
                if ( ptrs.attac_buff[atk] ) |num| {
                    ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                    ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                    ptrs.attacked.* = atk;
                } else {
                    const num = ptrs.attac_buff[last_atk].?;
                    ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                    ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                    ptrs.attacked.* = last_atk;
                }
            },
            .menu => {},
        }
    }

    if ( cursor_pos[0] < map_size_x - 1
        and (pad_diff & w4.BUTTON_RIGHT == w4.BUTTON_RIGHT or timer[2] == 0)
        and pad_new & w4.BUTTON_RIGHT == w4.BUTTON_RIGHT ) {
        timer[2] = gpad_timer_max;
        ptrs.redraw.* = true;
        switch (ptrs.cursor_state.*) {
            .initial, .selected => {
                cursor_pos[0] += 1;
            },
            .attack => {
                const atk = ptrs.attacked.* + 1;
                if ( ptrs.attac_buff[atk] ) |num| {
                    ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                    ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                    ptrs.attacked.* = atk;
                } else {
                    const num = ptrs.attac_buff[0].?;
                    ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                    ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                    ptrs.attacked.* = 0;
                }
            },
            .menu => {},
        }
    } else if ( cursor_pos[0] > 0
        and (pad_diff & w4.BUTTON_LEFT == w4.BUTTON_LEFT or timer[3] == 0)
        and pad_new & w4.BUTTON_LEFT == w4.BUTTON_LEFT ) {
        timer[3] = gpad_timer_max;
        ptrs.redraw.* = true;
        switch (ptrs.cursor_state.*) {
            .initial, .selected => {
                cursor_pos[0] -= 1;
            },
            .attack => {
                const last_atk = blk: {
                    var i: u4 = 1;
                    while ( ptrs.attac_buff[i] != null ) : ( i += 1 ) {}
                    break :blk i-1;
                };
                const atk = if (ptrs.attacked.* - 1 >= 0)
                    ptrs.attacked.* - 1 else last_atk;
                if ( ptrs.attac_buff[atk] ) |num| {
                    ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                    ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                    ptrs.attacked.* = atk;
                } else {
                    const num = ptrs.attac_buff[last_atk].?;
                    ptrs.cursor_pos[0] = ptrs.obj_pos[0][num];
                    ptrs.cursor_pos[1] = ptrs.obj_pos[1][num];
                    ptrs.attacked.* = last_atk;
                }
            },
            .menu => {},
        }
    }

    if ( pad_diff & w4.BUTTON_1 == w4.BUTTON_1
            and pad_new & w4.BUTTON_1 == w4.BUTTON_1 ) {
        ptrs.redraw.* = true;
        switch (ptrs.cursor_state.*) {
            .initial => {
                const n: ?ObjId = get_obj_num_on_cursor();

                if ( n != null and !ptrs.obj_info[n.?].acted ) {
                    const num = n.?;
                    calculate_movable_tiles(num);

                    ptrs.cursor_state.* = .selected;
                } else {
                    ptrs.cursor_state.* = .menu;
                }
            },
            .selected => {
                const offset = ptrs.selec_offset;
                const x = cursor_pos[0] - offset[0];
                const y = cursor_pos[1] - offset[1];
                if ( 0 <= x and x <= selected_range
                    and 0 <= y and y <= selected_range
                    and ptrs.selected[y][x] == 1 ) {
                    const center = (selected_range - 1) / 2;
                    const num = ptrs.selec_obj.*;
                    const obj_x = x + offset[0];
                    const obj_y = y + offset[1];
                    const team = ptrs.obj_info[num].team;

                    ptrs.obj_info[num].acted = true;
                    obj.moveTo(num, obj_x, obj_y);

                    offset[0] = obj_x - center;
                    offset[1] = obj_y - center;
                    ptrs.selected.* = .{.{0}**selected_range}**selected_range;

                    const selec_x = obj_x - offset[0];
                    const selec_y = obj_y - offset[1];
                    var i: u8 = 0;
                    if ( obj_y > 0 and ptrs.obj_map[obj_y-1][obj_x] != null ) {
                        const n2 = ptrs.obj_map[obj_y-1][obj_x].?;
                        if ( ptrs.obj_info[n2].team != team ) {
                            ptrs.selected[selec_y-1][selec_x] = 1;
                            ptrs.attac_buff[i] = n2;
                            i += 1;
                        }
                    }
                    if ( obj_x > 0 and ptrs.obj_map[obj_y][obj_x-1] != null ) {
                        const n2 = ptrs.obj_map[obj_y][obj_x-1].?;
                        if ( ptrs.obj_info[n2].team != team ) {
                            ptrs.selected[selec_y][selec_x-1] = 1;
                            ptrs.attac_buff[i] = n2;
                            i += 1;
                        }
                    }
                    if ( obj_x < map_size_y-1
                        and ptrs.obj_map[obj_y][obj_x+1] != null ) {
                        const n2 = ptrs.obj_map[obj_y][obj_x+1].?;
                        if ( ptrs.obj_info[n2].team != team ) {
                            ptrs.selected[selec_y][selec_x+1] = 1;
                            ptrs.attac_buff[i] = n2;
                            i += 1;
                        }
                    }
                    if ( obj_y < map_size_y-1
                        and ptrs.obj_map[obj_y+1][obj_x] != null ) {
                        const n2 = ptrs.obj_map[obj_y+1][obj_x].?;
                        if ( ptrs.obj_info[n2].team != team ) {
                            ptrs.selected[selec_y+1][selec_x] = 1;
                            ptrs.attac_buff[i] = n2;
                            i += 1;
                        }
                    }
                    ptrs.attacked.* = 0;
                    ptrs.attac_buff[i] = null;

                    if ( ptrs.attac_buff[0] ) |n2| {
                        ptrs.cursor_pos[0] = ptrs.obj_pos[0][n2];
                        ptrs.cursor_pos[1] = ptrs.obj_pos[1][n2];
                        ptrs.cursor_state.* = .attack;
                    } else {
                        ptrs.cursor_state.* = .initial;
                    }
                }
            },
            .attack => {
                const atk_num = ptrs.selec_obj.*;
                assert(ptrs.attac_buff[ptrs.attacked.*] != null);
                const def_num = ptrs.attac_buff[ptrs.attacked.*].?;

                obj.attack(atk_num, def_num);

                ptrs.cursor_state.* = .initial;
            },
            .menu => {},
        }
    } else if ( pad_diff & w4.BUTTON_2 == w4.BUTTON_2
            and pad_new & w4.BUTTON_2 == w4.BUTTON_2 ) {
        ptrs.redraw.* = true;
        switch (ptrs.cursor_state.*) {
            .initial => {},
            .selected => ptrs.cursor_state.* = .initial,
            .attack => {
                const num = ptrs.selec_obj.*;
                const old_x = ptrs.selec_pos[0];
                const old_y = ptrs.selec_pos[1];

                obj.moveTo(num, old_x, old_y);
                ptrs.cursor_pos.* = .{ old_x, old_y };

                calculate_movable_tiles(num);

                ptrs.cursor_state.* = .selected;
            },
            .menu => ptrs.cursor_state.* = .initial,
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
    const id = ptrs.obj_id[num];

    const center = (selected_range - 1) / 2;
    const range = id.range();

    const x = ptrs.cursor_pos[0] - center;
    const y = ptrs.cursor_pos[1] - center;
    ptrs.selec_offset[0] = x;
    ptrs.selec_offset[1] = y;
    ptrs.selec_obj.* = num;
    ptrs.selec_pos.* = ptrs.cursor_pos.*;

    for ( ptrs.selected ) |*ss, jj| {
        const j = @intCast(u8, jj);
        const dj = if ( j < center )
            center - j else j - center;
        for (ss) |*s, ii| {
            const i = @intCast(u8, ii);
            const di = if ( i < center )
                center - i else i - center;
            const empty_space = ptrs.obj_map[y+j][x+i] == null;
            const no_move = di + dj == 0;
            if ( di + dj <= range and (empty_space or no_move) ) {
                s.* = 1;
            } else {
                s.* = 0;
            }
        }
    }
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
        i = 0;
        while ( i < screen_tiles_x ) : ( i += 1 ) {
            const tile = map[cy+j][cx+i];
            switch (tile) {
                .mountain => {
                    w4.DRAW_COLORS.* = 0x43;
                    blit4(&g.square, (cx+i)*ts, (cy+j)*ts, 8, 8, 0);
                },
                .sea => {
                    w4.DRAW_COLORS.* = 0x44;
                    blit4(&g.square, (cx+i)*ts, (cy+j)*ts, 8, 8, 0);
                },
                else => {
                    w4.DRAW_COLORS.* = 0x21;
                    blit4(&g.sqr_border_q, (cx+i)*ts, (cy+j)*ts, 8, 8, 0);
                }
            }
        }
    }
    while ( j <= 10 ) : ( j += 1 ) {
        i = 0;
        while ( i <= 10 ) : ( i += 1 ) {
            w4.DRAW_COLORS.* = 0x43;
            blit4(&g.square, (cx+i)*ts, (cy+j)*ts, 8, 8, 0);
        }
    }

    switch (ptrs.cursor_state.*) {
        .initial, .menu => {},
        .selected, .attack => {
            const sx = ptrs.selec_offset[0];
            const sy = ptrs.selec_offset[1];
            for ( ptrs.selected ) |line, jj| {
                const sj = @intCast(u8, jj);
                for ( line ) |p, ii| {
                    const si = @intCast(u8, ii);
                    if ( p == 1 ) {
                        w4.DRAW_COLORS.* = 0x01;
                        blit4(&g.sqr_selected_q, (sx+si)*ts, (sy+sj)*ts, 8, 8, 0);
                    }
                }
            }
        },
    }
}

fn draw_cursor() void {
    const cursor_pos = ptrs.cursor_pos;
    const x = cursor_pos[0] * tilespace;
    const y = cursor_pos[1] * tilespace;
    w4.DRAW_COLORS.* = 0x03;

    switch (ptrs.cursor_state.*) {
        .initial, .selected =>
            blit4(&g.select_q, x, y, 8, 8, 0),
        .attack => blit4(&g.select_q, x, y, 8, 8, 4),
        .menu => blit4(&g.select_q, x, y, 8, 8, 6),
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
                const x = (cx+i) * tilespace + 4;
                const y = (cy+j) * tilespace + 4;
                const obj_info = ptrs.obj_info[num];

                // Health Bar
                const health = obj_info.health / 10 + 1;
                w4.DRAW_COLORS.* = 0x0004;
                if ( health <= 10 ) {
                    w4.rect(x - 1, y - 1, health, 1);
                    if ( health > 6 ) {
                        w4.DRAW_COLORS.* = 0x0003;
                        w4.rect(x - 1 + 4, y - 1, 2, 1);
                    } else if ( health == 5 ) {
                        w4.DRAW_COLORS.* = 0x0003;
                        w4.rect(x - 1 + 4, y - 1, 1, 1);
                    }
                }

                const color: u16 = switch (obj_info.team) {
                    0 => 0x0104,
                    1 => 0x0103,
                    2 => 0x0401,
                    3 => 0x0104,
                };
                if ( ptrs.obj_info[num].acted ) {
                    w4.DRAW_COLORS.* = color & 0xF0FF;
                } else {
                    w4.DRAW_COLORS.* = color;
                }

                // const rot = (@as(u8, @enumToInt(id)) % 8) << 1;
                switch (id) {
                    .infantry => blit(&g.infantry, x, y, 8, 8, 1),
                    .mech     => blit(&g.mech    , x, y, 8, 8, 1),
                    // else => blit(&g.smiley, x, y, 8, 8, rot),
                }
            }
        }
    }

}

fn blit(sprite: [*]const u8, x: i32, y: i32,
    width: i32, height: i32, flags: u32) void {
    w4.blit(sprite,
        x - (ptrs.cam[0]*tilespace),
        y - (ptrs.cam[1]*tilespace),
        width, height, flags);
}

fn blit4(sprite: [*]const u8, x: i32, y: i32,
    w: i32, h: i32, flags: u32) void {
    blit(sprite, x    , y    , w, h, flags ^ 0);
    blit(sprite, x + w, y    , w, h, flags ^ 2);
    blit(sprite, x    , y + h, w, h, flags ^ 4);
    blit(sprite, x + w, y + h, w, h, flags ^ 6);
}
