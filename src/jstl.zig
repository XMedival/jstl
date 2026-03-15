const std = @import("std");

const Vec3 = [3]f32;

const Triangle = struct {
    normal: Vec3,
    verts: [3]Vec3,
};

pub const Stl = struct {
    header: ?[80]u8,
    triangles: []Triangle,
    name: ?[]const u8,
};

pub fn open(r: *std.io.Reader, allocator: std.mem.Allocator) !Stl {
    if (std.mem.eql(u8, try r.peek(5), "solid")) {
        return try openAscii(r, allocator);
    } else {
        return try openBinary(r, allocator);
    }
}

fn discardWhitespace(r: *std.io.Reader) !void {
    while (true) {
        const c = try r.peekByte();
        if (std.ascii.isWhitespace(c)) {
            _ = try r.takeByte();
        } else break;
    }
}
fn parseVec3(s: []const u8) !Vec3 {
    var it = std.mem.tokenizeAny(u8, s, " \t");

    return .{
        try std.fmt.parseFloat(f32, it.next().?),
        try std.fmt.parseFloat(f32, it.next().?),
        try std.fmt.parseFloat(f32, it.next().?),
    };
}

fn parseVertex(line_opt: ?[]const u8) !Vec3 {
    const line = std.mem.trimLeft(u8, line_opt.?, " \t\r");

    if (!std.mem.startsWith(u8, line, "vertex"))
        return error.InvalidStl;

    return parseVec3(line["vertex".len..]);
}

fn openAscii(r: *std.io.Reader, allocator: std.mem.Allocator) !Stl {
    var triangles = try std.ArrayList(Triangle).initCapacity(allocator, 100);

    const first = try r.takeDelimiter('\n');
    const first_line = std.mem.trim(u8, first.?, " \t\r");

    if (!std.mem.startsWith(u8, first_line, "solid"))
        return error.InvalidStl;

    var name: ?[]const u8 = null;

    if (first_line.len > 5) {
        const raw = std.mem.trimLeft(u8, first_line[5..], " \t");
        name = try allocator.dupe(u8, raw);
    }

    while (true) {
        const line_opt = try r.takeDelimiter('\n');
        if (line_opt == null) break;

        const line = std.mem.trim(u8, line_opt.?, " \t\r");

        if (std.mem.startsWith(u8, line, "facet normal")) {
            const normal = try parseVec3(line["facet normal".len..]);

            _ = try r.takeDelimiter('\n'); // outer loop

            const v1 = try parseVertex(try r.takeDelimiter('\n'));
            const v2 = try parseVertex(try r.takeDelimiter('\n'));
            const v3 = try parseVertex(try r.takeDelimiter('\n'));

            _ = try r.takeDelimiter('\n'); // endloop
            _ = try r.takeDelimiter('\n'); // endfacet

            try triangles.append(allocator, .{
                .normal = normal,
                .verts = .{ v1, v2, v3 },
            });
        }

        if (std.mem.startsWith(u8, line, "endsolid"))
            break;
    }

    return Stl{
        .header = null,
        .triangles = try triangles.toOwnedSlice(allocator),
        .name = name,
    };
}

fn openBinary(r: *std.io.Reader, allocator: std.mem.Allocator) !Stl {
    var ret: Stl = .{
        .header = null,
        .name = null,
        .triangles = &.{},
    };
    var header: [80]u8 = undefined;
    try r.readSliceAll(&header);
    const triangle_count = try r.takeInt(u32, .little);
    var triangles = try std.ArrayList(Triangle).initCapacity(allocator, triangle_count);
    for (0..triangle_count) |_| {
        const triangle: Triangle = .{
            .normal = .{
                @bitCast(try r.takeInt(u32, .little)),
                @bitCast(try r.takeInt(u32, .little)),
                @bitCast(try r.takeInt(u32, .little)),
            },
            .verts = .{
                .{
                    @bitCast(try r.takeInt(u32, .little)),
                    @bitCast(try r.takeInt(u32, .little)),
                    @bitCast(try r.takeInt(u32, .little)),
                },
                .{
                    @bitCast(try r.takeInt(u32, .little)),
                    @bitCast(try r.takeInt(u32, .little)),
                    @bitCast(try r.takeInt(u32, .little)),
                },
                .{
                    @bitCast(try r.takeInt(u32, .little)),
                    @bitCast(try r.takeInt(u32, .little)),
                    @bitCast(try r.takeInt(u32, .little)),
                },
            }
        };
        try r.discardAll(2);
        try triangles.append(allocator, triangle);
    }
    ret.triangles = try triangles.toOwnedSlice(allocator);
    ret.header = header;
    return ret;
}
