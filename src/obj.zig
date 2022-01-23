const assert = @import("std").debug.assert;

const main = @import("main.zig");
const utils = @import("utils.zig");
const w4 = main.w4;

const ptrs = main.ptrs;
const info = main.info;

const ObjId = main.ObjId;
const Team = main.Team;

const max_health = main.max_health;
const team_cnt = main.team_cnt;
const unity_cap = main.unity_cap;

pub fn create(id: info.Unity_Id, team: Team, x: u8, y: u8) ObjId {
    const num = blk: {
        const freed_cnt = ptrs.freed_cnt[team];
        if ( freed_cnt > 0 ) {
            const num = ptrs.freed_list[team][freed_cnt - 1];
            ptrs.freed_cnt[team] = freed_cnt - 1;
            break :blk num + team * @as(ObjId, unity_cap);
        } else {
            const num = ptrs.next_obj[team];
            ptrs.next_obj[team] += 1;
            break :blk num + team * @as(ObjId, unity_cap);
        }
    };
    ptrs.obj_id[num] = id;
    ptrs.obj_info[num] = .{
        .acted = true,
        .health = max_health,
        .team = team,
        .fuel = id.max_fuel(),
        .transporting = null,
    };
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
    const team = num / unity_cap;
    const freed_cnt = ptrs.freed_cnt[team];
    const list = &ptrs.freed_list[team];
    const next_obj = ptrs.next_obj[team];

    if ( num == next_obj - 1 ) {
        var unfreed: u7 = 0;
        var i: u7 = 0;
        while ( list[i] == next_obj - 1 - unfreed
            and i < freed_cnt ) : ( i += 1 ) {
            unfreed += 1;
        }
        if ( unfreed > 0 ) {
            while ( i < freed_cnt ) : ( i += 1 ) {
                list[i - unfreed] = list[i];
            }
            ptrs.freed_cnt[team] -= unfreed;
        }
        ptrs.next_obj[team] -= (unfreed + 1);
    } else {
        var n = num;
        var i: u7 = 0;
        while ( i < freed_cnt ) : ( i += 1 ) {
            if ( list[i] < n ) {
                const tmp = list[i];
                list[i] = n;
                n = tmp;
            } else if ( list[i] == n ) {
                w4.trace("obj.delete: double delete detected!");
                unreachable;
            }
        }
        list[i] = n;
        ptrs.freed_cnt[team] = freed_cnt + 1;
    }

    if ( ptrs.next_obj[team] == team * unity_cap ) {
        var i: u2 = team_cnt;
        for ( ptrs.next_obj ) |army_cnt| {
            if ( army_cnt == 0 ) i -= 1;
        }
        if ( i == 1 ) {
            ptrs.game_state.* = switch ( team ) {
                0 => .army0,
                1 => .army1,
                else => .army0,
            };
        }
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

pub fn supply(num: ObjId) void {
    const id = ptrs.obj_id[num];
    const this_obj_info = &ptrs.obj_info[num];
    this_obj_info.*.fuel = id.max_fuel();
}

pub fn join(num: ObjId, mvd_num: ObjId, id: info.Unity_Id) void {
    if ( num == mvd_num ) {
        w4.trace("obj.join: same obj_ids");
        w4.tracef("num: %d moved: %d", num, mvd_num);
        unreachable;
    }
    const num_id = ptrs.obj_id[num];
    const mvd_id = ptrs.obj_id[mvd_num];
    if ( num_id != id or mvd_id != id ) {
        w4.trace("obj.join: id differ");
        w4.tracef("num_id: %d moved_id: %d reference_id: %d",
            num_id, mvd_id, id);
        unreachable;
    }

    const obj_info = &ptrs.obj_info[num];
    const mvd_info = &ptrs.obj_info[mvd_num];

    if ( obj_info.team != mvd_info.team ) {
        w4.trace("obj.join: team differ");
        w4.tracef("num team: %d moved team: %d",
            obj_info.team, mvd_info.team);
        unreachable;
    }

    if ( obj_info.transporting != null
        or mvd_info.transporting != null ) {
        w4.trace("obj.join: both are transporting something");
        w4.tracef("num team: %d moved team: %d",
            obj_info.team, mvd_info.team);
        unreachable;
    }

    obj_info.* = .{
        .acted = true,
        .team = obj_info.team,
        .health = utils.min(u7,
            obj_info.health +| mvd_info.health, max_health),
        .fuel = utils.min(u7,
            obj_info.fuel +| mvd_info.fuel, id.max_fuel()),
        .transporting = obj_info.transporting
            orelse mvd_info.transporting orelse null,
    };

    delete(mvd_num);
}

pub fn calc_attack(atk_num: ObjId, def_num: ObjId) !u7 {
    const atk_id = ptrs.obj_id[atk_num];
    const def_id = ptrs.obj_id[def_num];

    const atk_info = ptrs.obj_info[atk_num];
    const def_info = ptrs.obj_info[def_num];

    const atk_health = (@as(u16, atk_info.health) / 10) * 10;
    const def_health = (@as(u16, def_info.health) / 10) * 10;

    // TODO: Add co lookup
    const co_atk_bonus = 100;
    const co_def_bonus = 100;

    // TODO: Add luck calculation (0 ~ 9)
    const luck = 0;

    const can_attack = atk_id.attack(def_id);
    if ( can_attack == null ) {
        return error.CannotAttack;
    }
    const base_damage =
        @as(u16, can_attack.?) * co_atk_bonus / 100 + luck;

    const defense = blk: {
        const def_x = ptrs.obj_pos[0][def_num];
        const def_y = ptrs.obj_pos[1][def_num];
        const tile = ptrs.map[def_y][def_x];
        break :blk @as(u16, tile.defense());
    };

    const pre_def_damage = base_damage * atk_health / 100;

    const total_damage = pre_def_damage
        * (200 - co_def_bonus - defense * def_health / 10) / 100;

    if ( !(0 <= total_damage and total_damage < 0x80) ) {
        w4.trace("calc_attack:");
        w4.tracef("  atk_id: %d", @enumToInt(atk_id));
        w4.tracef("  def_id: %d", @enumToInt(def_id));
        w4.tracef("  base_damage: %d", base_damage);
        w4.tracef("  pre_def_damage: %d", pre_def_damage);
        w4.tracef("  total_damage: %d", total_damage);
        unreachable;
    }
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

    const atk_damage = calc_attack(atk_num, def_num)
        catch |err| switch (err) {
            error.CannotAttack => {
                w4.trace("obj.atack: found error: Cannot Attack");
                w4.tracef("atk_num: %d def_num: %d",
                    atk_num, def_num);
                unreachable;
            },
    };

    var def_health: u7 = undefined;
    if ( !@subWithOverflow(u7, def_info.*.health, atk_damage,
            &def_health) ) {
        def_info.*.health = @intCast(u7, def_health);

        const def_damage = calc_attack(def_num, atk_num)
            catch |err| switch (err) {
                error.CannotAttack => 0,
        };

        var atk_health: u7 = undefined;
        if ( !@subWithOverflow(u7, atk_info.*.health, def_damage,
                &atk_health) ) {
            atk_info.*.health = atk_health;
        } else {
            delete(atk_num);
        }
    } else {
        delete(def_num);
    }

    ptrs.obj_info[atk_num].acted = true;
}
