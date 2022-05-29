module emu.hw.gpu.gpu3d.geometry_engine;

import emu;
import util;

struct GPU3DCommand {
    this(string name, int id, int num_parameters, int cycles, bool implemented) {
        this.name           = name;
        this.id             = id;
        this.num_parameters = num_parameters;
        this.cycles         = cycles;
        this.valid          = true;
        this.implemented    = implemented;
    }

    string name;
    int id;
    int num_parameters;

    // probably not going to use this field because i want to avoid abusing
    // my scheduler, but it's here if i ever decide to implement it in the future
    int cycles;
    bool implemented;

    bool valid;
}

__gshared GeometryEngine geometry_engine;
final class GeometryEngine {
    struct MatrixStack(int size) {
        Mat4x4[size] stack;
        int stack_pointer = 0;

        void push(Mat4x4 matrix) {
            if (stack_pointer == size) return;

            stack[stack_pointer] = matrix;
            stack_pointer++;
        }

        Mat4x4 pop(int n) {
            stack_pointer -= n;
            if (stack_pointer < 0) stack_pointer = 0;
            if (stack_pointer >= size) stack_pointer = size;

            return stack[stack_pointer];
        }

        void store(Mat4x4 matrix, int index) {
            stack[index] = matrix;
        }

        Mat4x4 restore(int index) {
            return stack[index - 1];
        }
    }

    enum State {
        RECEIVING_COMMAND,
        RECEIVING_PARAMETERS
    }

    enum MatrixMode {
        PROJECTION      = 0,
        POSITION        = 1,
        POSITION_VECTOR = 2,
        TEXTURE         = 3
    }

    enum PolygonType {
        TRIANGLES            = 0,
        QUADRILATERALS       = 1,
        TRIANGLE_STRIPS      = 2,
        QUADRILATERAL_STRIPS = 3
    }

    enum TextureTransformationMode {
        NONE     = 0,
        TEXCOORD = 1,
        NORMAL   = 2,
        VERTEX   = 3
    }

    GPU3D parent;

    MatrixMode matrix_mode;
    State state = State.RECEIVING_COMMAND;
    PolygonType polygon_type;
    int current_command_id;

    GPU3DCommand[4] command_buffer;
    int command_buffer_length;
    int current_command_index;

    Word[32] command_parameters_buffer;
    int command_parameters_length;
    int command_parameters_remaining;

    MatrixStack!32 projection_stack;
    MatrixStack!32 modelview_stack;
    MatrixStack!1  position_vector_stack;
    MatrixStack!1  texture_stack;

    Mat4x4 projection_matrix;
    Mat4x4 modelview_matrix;
    Mat4x4 position_vector_matrix;
    Mat4x4 texture_matrix;

    int current_color_r;
    int current_color_g;
    int current_color_b;

    TriangleAssembler       triangle_assembler;
    QuadAssembler           quad_assembler;
    TriangleStripsAssembler triangle_strips_assembler;
    QuadStripsAssembler     quad_strips_assembler;

    Word palette_base_address;

    Vec4 previous_vertex;
    bool receiving_vtxs;

    int polygon_index = 0;

    Word upcoming_polygon_attributes;

    int texture_vram_offset;
    bool texture_repeat_s_direction;
    bool texture_repeat_t_direction;
    bool texture_flip_s_direction;
    bool texture_flip_t_direction;
    int texture_s_size;
    int texture_t_size;
    TextureFormat texture_format;
    bool texture_color_0_transparent;
    TextureTransformationMode texture_transformation_mode;

    bool texture_mapped;
    
    Vec4 texcoord_prime;
    Vec4 normal_vector;

    this(GPU3D parent) {
        this.parent = parent;
        
        triangle_assembler        = new TriangleAssembler();
        quad_assembler            = new QuadAssembler();
        triangle_strips_assembler = new TriangleStripsAssembler();
        quad_strips_assembler     = new QuadStripsAssembler();

        geometry_engine = this;
    }

    void multiply_matrix(Mat4x4 matrix) {
        final switch (matrix_mode) {
            case MatrixMode.PROJECTION:
                projection_matrix = projection_matrix * matrix;
                break;

            case MatrixMode.POSITION:
                modelview_matrix = modelview_matrix * matrix;
                break;

            case MatrixMode.POSITION_VECTOR:
                position_vector_matrix = position_vector_matrix * matrix;
                modelview_matrix       = modelview_matrix * matrix;
                break;
            
            case MatrixMode.TEXTURE:
                texture_matrix = texture_matrix * matrix;
                break;
        }
    }

    PolygonAssembler get_assembler() {
        final switch (polygon_type) {
            case PolygonType.TRIANGLES:
                return triangle_assembler;
            
            case PolygonType.QUADRILATERALS:
                return quad_assembler;

            case PolygonType.TRIANGLE_STRIPS:
                return triangle_strips_assembler;
            
            case PolygonType.QUADRILATERAL_STRIPS:
                return quad_strips_assembler;
        }
    }

    void submit_vertex(Vec4 vertex) {
        previous_vertex = vertex;
        vertex = (projection_matrix * modelview_matrix) * vertex;

        PolygonAssembler assembler = get_assembler();

        if (assembler.submit_vertex(
            Vertex(
                vertex,
                current_color_r,
                current_color_g,
                current_color_b,
                texcoord_prime
            )
        )) {
            auto polygon = assembler.get_polygon();
            polygon.uses_textures               = texture_mapped;
            polygon.texture_vram_offset         = texture_vram_offset;
            polygon.texture_repeat_s_direction  = texture_repeat_s_direction;
            polygon.texture_repeat_t_direction  = texture_repeat_t_direction;
            polygon.texture_flip_s_direction    = texture_flip_s_direction;
            polygon.texture_flip_t_direction    = texture_flip_t_direction;
            polygon.texture_s_size              = texture_s_size;
            polygon.texture_t_size              = texture_t_size;
            polygon.texture_format              = texture_format;
            polygon.texture_color_0_transparent = texture_color_0_transparent;

            parent.geometry_buffer[polygon_index] = polygon;
            polygon_index++;
        }
    }

    void set_current_matrix(Mat4x4 matrix) {
        final switch (matrix_mode) {
            case MatrixMode.PROJECTION:
                projection_matrix = matrix;
                break;

            case MatrixMode.POSITION:
                modelview_matrix = matrix;
                break;

            case MatrixMode.POSITION_VECTOR:
                position_vector_matrix = matrix;
                modelview_matrix       = matrix;
                break;
            
            case MatrixMode.TEXTURE:
                texture_matrix = matrix;
                break;
        }
    }

    void handle_MTX_MODE(Word* args) {
        matrix_mode = cast(MatrixMode) args[0][0..1];
    }

    void handle_MTX_PUSH(Word* args) {
        final switch (matrix_mode) {
            case MatrixMode.PROJECTION:
                projection_stack.push(projection_matrix);
                break;

            case MatrixMode.POSITION:
                modelview_stack.push(modelview_matrix);
                break;

            case MatrixMode.POSITION_VECTOR: 
                modelview_stack.push(modelview_matrix);
                position_vector_stack.push(position_vector_matrix);
                break;

            case MatrixMode.TEXTURE:
                texture_stack.push(texture_matrix);
                break;
        }
    }

    void handle_MTX_POP(Word* args) {
        final switch (matrix_mode) {
            case MatrixMode.PROJECTION: 
                projection_matrix = projection_stack.pop(1);
                break;

            case MatrixMode.POSITION:
                modelview_matrix = modelview_stack.pop(sext_32(args[0][0..5], 6));
                break;

            case MatrixMode.POSITION_VECTOR:
                modelview_matrix = modelview_stack.pop(sext_32(args[0][0..5], 6));
                position_vector_matrix = position_vector_stack.pop(sext_32(args[0][0..5], 6));
                break;

            case MatrixMode.TEXTURE:
                texture_matrix = texture_stack.pop(1);
                break;
        }
    }

    void handle_MTX_STORE(Word* args) {
        final switch (matrix_mode) {
            case MatrixMode.PROJECTION: 
                projection_stack.store(projection_matrix, args[0][0..4]);
                break;

            case MatrixMode.POSITION:
                modelview_stack.store(modelview_matrix, args[0][0..4]);
                break;

            case MatrixMode.POSITION_VECTOR: 
                modelview_stack.store(modelview_matrix, args[0][0..4]);
                position_vector_stack.store(position_vector_matrix, 0);
                break;

            case MatrixMode.TEXTURE:
                texture_stack.store(texture_matrix, 0);
                break;
        }
    }

    void handle_MTX_RESTORE(Word* args) {
        final switch (matrix_mode) {
            case MatrixMode.PROJECTION: 
                projection_matrix = projection_stack.restore(args[0][0..4]);
                break;

            case MatrixMode.POSITION:
                modelview_matrix = modelview_stack.restore(args[0][0..4]);
                break;

            case MatrixMode.POSITION_VECTOR:
                modelview_matrix = modelview_stack.restore(args[0][0..4]);
                position_vector_matrix = position_vector_stack.restore(1);
                break;

            case MatrixMode.TEXTURE:
                texture_matrix = texture_stack.restore(1);
                break;
        }
    }

    void handle_MTX_IDENTITY(Word* args) {
        final switch (matrix_mode) {
            case MatrixMode.PROJECTION: 
                arm9.num_log = 1000;
                projection_matrix = Mat4x4.identity();
                break;

            case MatrixMode.POSITION:
                modelview_matrix = Mat4x4.identity();
                break;

            case MatrixMode.POSITION_VECTOR:
                modelview_matrix = Mat4x4.identity();
                position_vector_matrix = Mat4x4.identity();
                break;

            case MatrixMode.TEXTURE:
                texture_matrix = Mat4x4.identity();
                break;
        }
    }

    void handle_POLYGON_ATTR(Word* args) {
        upcoming_polygon_attributes = args[0];
    }

    void handle_VIEWPORT(Word* args) {
        parent.viewport_x1 = args[0].get_byte(0);
        parent.viewport_y1 = args[0].get_byte(1);
        parent.viewport_x2 = args[0].get_byte(2);
        parent.viewport_y2 = args[0].get_byte(3);
    }

    void handle_PLTT_BASE(Word* args) {
        palette_base_address = args[0][0..12];
    }

    void handle_MTX_LOAD_4x4(Word* args) {
        auto convert = (Word x) => signed_fixed_point_to_float!12(x); 
        
        set_current_matrix(
            Mat4x4([
                [convert(args[0]), convert(args[4]), convert(args[8]),  convert(args[12])],
                [convert(args[1]), convert(args[5]), convert(args[9]),  convert(args[13])],
                [convert(args[2]), convert(args[6]), convert(args[10]), convert(args[14])],
                [convert(args[3]), convert(args[7]), convert(args[11]), convert(args[15])],
            ])
        );
    }

    void handle_MTX_LOAD_4x3(Word* args) {
        auto convert = (Word x) => signed_fixed_point_to_float!12(x); 

        set_current_matrix(
            Mat4x4([
                [convert(args[0]), convert(args[3]),  convert(args[6]),  convert(args[9])],
                [convert(args[1]), convert(args[4]),  convert(args[7]),  convert(args[10])],
                [convert(args[2]), convert(args[5]),  convert(args[8]),  convert(args[11])],
                [0.0f,             0.0f,              0.0f,              1.0f],
            ])
        );
    }

    void handle_MTX_MULT_4x4(Word* args) {
        auto convert = (Word x) => signed_fixed_point_to_float!12(x);

        multiply_matrix(Mat4x4([
            [convert(args[0]), convert(args[4]), convert(args[8]),  convert(args[12])],
            [convert(args[1]), convert(args[5]), convert(args[9]),  convert(args[13])],
            [convert(args[2]), convert(args[6]), convert(args[10]), convert(args[14])],
            [convert(args[3]), convert(args[7]), convert(args[11]), convert(args[15])],
        ]));
    }

    void handle_MTX_MULT_4x3(Word* args) {
        auto convert = (Word x) => signed_fixed_point_to_float!12(x);

        multiply_matrix(Mat4x4([
            [convert(args[0]), convert(args[3]),  convert(args[6]),  convert(args[9])],
            [convert(args[1]), convert(args[4]),  convert(args[7]),  convert(args[10])],
            [convert(args[2]), convert(args[5]),  convert(args[8]),  convert(args[11])],
            [0.0f,             0.0f,              0.0f,              1.0f],
        ]));
    }

    void handle_MTX_MULT_3x3(Word* args) {
        auto convert = (Word x) => signed_fixed_point_to_float!12(x);

        multiply_matrix(Mat4x4([
            [convert(args[0]), convert(args[3]),  convert(args[6]),  0.0f],
            [convert(args[1]), convert(args[4]),  convert(args[7]),  0.0f],
            [convert(args[2]), convert(args[5]),  convert(args[8]),  0.0f],
            [0.0f,             0.0f,              0.0f,              1.0f],
        ]));
    }

    void handle_MTX_TRANS(Word* args) {
        auto convert = (Word x) => signed_fixed_point_to_float!12(x);

        multiply_matrix(Mat4x4([
            [1.0f, 0.0f, 0.0f, convert(args[0])],
            [0.0f, 1.0f, 0.0f, convert(args[1])],
            [0.0f, 0.0f, 1.0f, convert(args[2])],
            [0.0f, 0.0f, 0.0f, 1.0f],
        ]));
    }

    void handle_BEGIN_VTXS(Word* args) {
        polygon_type = cast(PolygonType) args[0][0..1];
        receiving_vtxs = true;

        PolygonAssembler assembler = get_assembler();
        assembler.reset();
    }

    void handle_END_VTXS(Word* args) {
        receiving_vtxs = false;
    }

    void handle_VTX_16(Word* args) {
        submit_vertex(Vec4([
            signed_fixed_point_to_float!12(sext_32!Word(Word(args[0][0..15]), 16)),
            signed_fixed_point_to_float!12(sext_32!Word(Word(args[0][16..31]), 16)),
            signed_fixed_point_to_float!12(sext_32!Word(Word(args[1][0..15]), 16)),
            1.0f
        ]));
    }

    void handle_VTX_10(Word* args) {
        submit_vertex(Vec4([
            signed_fixed_point_to_float!9(sext_32!Word(Word(args[0][0..9]), 16)),
            signed_fixed_point_to_float!9(sext_32!Word(Word(args[0][10..19]), 16)),
            signed_fixed_point_to_float!9(sext_32!Word(Word(args[0][20..29]), 16)),
            1.0f
        ]));
    }

    void handle_VTX_XY(Word* args) {
        submit_vertex(Vec4([
            signed_fixed_point_to_float!12(sext_32!Word(Word(args[0][0..15]), 16)),
            signed_fixed_point_to_float!12(sext_32!Word(Word(args[0][16..31]), 16)),
            previous_vertex[2],
            1.0f
        ]));
    }

    void handle_VTX_XZ(Word* args) {
        submit_vertex(Vec4([
            signed_fixed_point_to_float!12(sext_32!Word(Word(args[0][0..15]), 16)),
            previous_vertex[1],
            signed_fixed_point_to_float!12(sext_32!Word(Word(args[0][16..31]), 16)),
            1.0f
        ]));
    }

    void handle_VTX_YZ(Word* args) {
        submit_vertex(Vec4([
            previous_vertex[0],
            signed_fixed_point_to_float!12(sext_32!Word(Word(args[0][0..15]), 16)),
            signed_fixed_point_to_float!12(sext_32!Word(Word(args[0][16..31]), 16)),
            1.0f
        ]));
    }

    void handle_VTX_DIFF(Word* args) {
        submit_vertex(Vec4([
            signed_fixed_point_to_float!9(sext_32!Word(Word(args[0][0..9]),   10)) / 8 + previous_vertex[0],
            signed_fixed_point_to_float!9(sext_32!Word(Word(args[0][10..19]), 10)) / 8 + previous_vertex[1],
            signed_fixed_point_to_float!9(sext_32!Word(Word(args[0][20..29]), 10)) / 8 + previous_vertex[2],
            1.0f
        ]));
    }

    void handle_SWAP_BUFFERS(Word* args) {
        parent.swap_buffers(polygon_index);
        polygon_index = 0;
    }

    void handle_COLOR(Word* args) {
        current_color_r = args[0][0 .. 4];
        current_color_g = args[0][5 .. 9];
        current_color_b = args[0][10..14];
        texture_mapped = false;
    }

    void handle_TEXIMAGE_PARAM(Word* args) {
        texture_vram_offset         = args[0][0..15];
        texture_repeat_s_direction  = args[0][16];
        texture_repeat_t_direction  = args[0][17];
        texture_flip_s_direction    = args[0][18];
        texture_flip_t_direction    = args[0][19];
        texture_s_size              = args[0][20..22];
        texture_t_size              = args[0][23..25];
        texture_format              = cast(TextureFormat) args[0][26..28];
        texture_color_0_transparent = args[0][29];
        texture_transformation_mode = cast(TextureTransformationMode) args[0][30..31];
    }

    void handle_TEXCOORD(Word* args) {
        auto convert = (Word x) => signed_fixed_point_to_float!4(sext_32!Word(Word(x), 16));
        Vec4 texcoord = Vec4([convert(args[0][0..15]), convert(args[0][16..31]), 0.0f, 0.0f]);

        final switch (texture_transformation_mode) {
            case TextureTransformationMode.NONE:
                texcoord_prime = texcoord;
                break;

            case TextureTransformationMode.TEXCOORD:
                texcoord_prime = texture_matrix * texcoord;
                break;
            
            case TextureTransformationMode.NORMAL:
                texture_matrix[3][0] = texcoord[0];
                texture_matrix[3][1] = texcoord[1];
                texcoord_prime = texture_matrix * normal_vector;
                break;
            
            case TextureTransformationMode.VERTEX:
                texture_matrix[3][0] = texcoord[0];
                texture_matrix[3][1] = texcoord[1];
                texcoord_prime = texture_matrix * previous_vertex;
                break;
        }
        
        texture_mapped = true;
    }

    void handle_NORMAL(Word* args) {
        auto convert = (Word x) => signed_fixed_point_to_float!9(sext_32!Word(Word(x), 10));
        normal_vector = Vec4([
            convert(args[0][0..9]),
            convert(args[0][10..19]),
            convert(args[0][20..29]),
            1.0f
        ]);
    }

    void push_command(Word data) {
        final switch (state) {
            case State.RECEIVING_COMMAND:
                command_buffer_length = 0;
                for (int i = 0; i < 4; i++) {
                    if (data.get_byte(i) != 0) {
                        auto command = commands[data.get_byte(i)];
                        if (!command.valid) error_gpu3d("Invalid command! %x", data.get_byte(i));

                        command_buffer[command_buffer_length] = command;
                        command_buffer_length++;
                        current_command_index = 0;
                        command_parameters_length = 0;
                    }
                }

                if (command_buffer_length > 0) {
                    command_parameters_remaining = command_buffer[0].num_parameters;
                    state = State.RECEIVING_PARAMETERS;
                    if (command_parameters_remaining == 0) goto case State.RECEIVING_PARAMETERS;
                }
                break;
            
            case State.RECEIVING_PARAMETERS:
                if (command_parameters_remaining != 0) {
                    command_parameters_buffer[command_parameters_length] = data;
                    command_parameters_remaining--;
                    command_parameters_length++;
                }

                while (command_parameters_remaining == 0) {
                    log_gpu3d("Received well-formed command: %s", command_buffer[current_command_index].name);
                    this.handle_command(command_buffer[current_command_index].id, cast(Word*) command_parameters_buffer);

                    current_command_index++;

                    if (current_command_index == command_buffer_length) {
                        state = State.RECEIVING_COMMAND;
                        break;
                    } else {
                        command_parameters_remaining = command_buffer[current_command_index].num_parameters;
                    }
                }
                break;
        }
    }

    void write_GXFIFO(T)(T data, int offset) {
        static if (!is(T == Word)) {
            error_gpu3d("Tried to write a non-Word value to GXFIFO");
        } else {
            push_command(data);
        }
    }

    static foreach (i; 0 .. 256) {
        import std.format;

        static if (commands[i].valid) {
            mixin("
                void write_%s(T)(T data, int offset) {
                    if (state == State.RECEIVING_COMMAND) {
                        push_command(Word(%d));
                    } else {
                        if (command_buffer[current_command_index].id != %d) {
                            error_gpu3d(\"Tried to start two commands at once!\");
                        }
                    }
                        
                    push_command(Word(data));
                }
            ".format(commands[i].name, i, i));
        }
    }

    void handle_command(int command, Word* args) {
        switch (command) {
            import std.format;
            static foreach (i; 0 .. 256) {
                static if (commands[i].valid) {
                    case i:
                        static if (commands[i].implemented) {
                            mixin("this.handle_%s(args);".format(commands[i].name));
                        } else {
                            log_gpu3d("Unhandled command: %s", commands[i].name);
                        }
                        return;
                }
            }

            default:
                error_gpu3d("Improper command: %x", command);
        }
    }
}

static GPU3DCommand[256] generate_commands()() {
    GPU3DCommand[256] commands;

    commands[0x10] = GPU3DCommand("MTX_MODE",         0x10, 1,  1,   true);
    commands[0x11] = GPU3DCommand("MTX_PUSH",         0x11, 0,  17,  true);
    commands[0x12] = GPU3DCommand("MTX_POP",          0x12, 1,  36,  true);
    commands[0x13] = GPU3DCommand("MTX_STORE",        0x13, 1,  17,  true);
    commands[0x14] = GPU3DCommand("MTX_RESTORE",      0x14, 1,  36,  true);
    commands[0x15] = GPU3DCommand("MTX_IDENTITY",     0x15, 0,  19,  true);
    commands[0x16] = GPU3DCommand("MTX_LOAD_4x4",     0x16, 16, 34,  true);
    commands[0x17] = GPU3DCommand("MTX_LOAD_4x3",     0x17, 12, 30,  true);
    commands[0x18] = GPU3DCommand("MTX_MULT_4x4",     0x18, 16, 35,  true);
    commands[0x19] = GPU3DCommand("MTX_MULT_4x3",     0x19, 12, 31,  true);
    commands[0x1A] = GPU3DCommand("MTX_MULT_3x3",     0x1A, 9,  28,  true);
    commands[0x1B] = GPU3DCommand("MTX_SCALE",        0x1B, 3,  22,  false);
    commands[0x1C] = GPU3DCommand("MTX_TRANS",        0x1C, 3,  22,  true);
    commands[0x20] = GPU3DCommand("COLOR",            0x20, 1,  1,   true);
    commands[0x21] = GPU3DCommand("NORMAL",           0x21, 1,  9,   true);
    commands[0x22] = GPU3DCommand("TEXCOORD",         0x22, 1,  1,   true);
    commands[0x23] = GPU3DCommand("VTX_16",           0x23, 2,  9,   true);
    commands[0x24] = GPU3DCommand("VTX_10",           0x24, 1,  8,   true);
    commands[0x25] = GPU3DCommand("VTX_XY",           0x25, 1,  8,   true);
    commands[0x26] = GPU3DCommand("VTX_XZ",           0x26, 1,  8,   true);
    commands[0x27] = GPU3DCommand("VTX_YZ",           0x27, 1,  8,   true);
    commands[0x28] = GPU3DCommand("VTX_DIFF",         0x28, 1,  8,   true);
    commands[0x29] = GPU3DCommand("POLYGON_ATTR",     0x29, 1,  1,   true);
    commands[0x2A] = GPU3DCommand("TEXIMAGE_PARAM",   0x2A, 1,  1,   true);
    commands[0x2B] = GPU3DCommand("PLTT_BASE",        0x2B, 1,  1,   true);
    commands[0x30] = GPU3DCommand("DIF_AMB",          0x30, 1,  4,   false);
    commands[0x31] = GPU3DCommand("SPE_EMI",          0x31, 1,  4,   false);
    commands[0x32] = GPU3DCommand("LIGHT_VECTOR",     0x32, 1,  6,   false);
    commands[0x33] = GPU3DCommand("LIGHT_COLOR",      0x33, 1,  1,   false);
    commands[0x34] = GPU3DCommand("SHININESS",        0x34, 32, 32,  false);
    commands[0x40] = GPU3DCommand("BEGIN_VTXS",       0x40, 1,  1,   true);
    commands[0x41] = GPU3DCommand("END_VTXS",         0x41, 0,  1,   true);
    commands[0x50] = GPU3DCommand("SWAP_BUFFERS",     0x50, 1,  392, true);
    commands[0x60] = GPU3DCommand("VIEWPORT",         0x60, 1,  1,   true);
    commands[0x70] = GPU3DCommand("BOX_TEST",         0x70, 3,  103, false);
    commands[0x71] = GPU3DCommand("POS_TEST",         0x71, 2,  9,   false);
    commands[0x72] = GPU3DCommand("VEC_TEST",         0x72, 1,  5,   false);

    return commands;
}

immutable GPU3DCommand[256] commands = generate_commands!();