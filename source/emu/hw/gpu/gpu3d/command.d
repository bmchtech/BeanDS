module emu.hw.gpu.gpu3d.command;

import emu;
import util;

struct GPU3DCommand {
    this(string name, int num_parameters, int cycles) {
        this.name           = name;
        this.num_parameters = num_parameters;
        this.cycles         = cycles;
        this.valid          = true;
    }

    string name;
    int num_parameters;

    // probably not going to use this field because i want to avoid abusing
    // my scheduler, but it's here if i ever decide to implement it in the future
    int cycles;

    bool valid;
}

static GPU3DCommand[256] generate_commands()() {
    GPU3DCommand[256] commands;

    commands[0x10] = GPU3DCommand("MTX_MODE",        1,  1);
    commands[0x11] = GPU3DCommand("MTX_PUSH",        0,  17);
    commands[0x12] = GPU3DCommand("MTX_POP",         1,  36);
    commands[0x13] = GPU3DCommand("MTX_STORE",       1,  17);
    commands[0x14] = GPU3DCommand("MTX_RESTORE",     1,  36);
    commands[0x15] = GPU3DCommand("MTX_IDENTITY",    0,  19);
    commands[0x16] = GPU3DCommand("MTX_LOAD_4x4",    16, 34);
    commands[0x17] = GPU3DCommand("MTX_LOAD_4x3",    12, 30);
    commands[0x18] = GPU3DCommand("MTX_MULT_4x4",    16, 35);
    commands[0x19] = GPU3DCommand("MTX_MULT_4x3",    12, 31);
    commands[0x1A] = GPU3DCommand("MTX_MULT_3x3",    9,  28);
    commands[0x1B] = GPU3DCommand("MTX_SCALE",       3,  22);
    commands[0x1C] = GPU3DCommand("MTX_TRANS",       3,  22);
    commands[0x20] = GPU3DCommand("COLOR",           1,  1);
    commands[0x21] = GPU3DCommand("NORMAL",          1,  9);
    commands[0x22] = GPU3DCommand("TEXCOORD",        1,  1);
    commands[0x23] = GPU3DCommand("VTX_16",          2,  9);
    commands[0x24] = GPU3DCommand("VTX_10",          1,  8);
    commands[0x25] = GPU3DCommand("VTX_XY",          1,  8);
    commands[0x26] = GPU3DCommand("VTX_XZ",          1,  8);
    commands[0x27] = GPU3DCommand("VTX_YZ",          1,  8);
    commands[0x28] = GPU3DCommand("VTX_DIFF",        1,  8);
    commands[0x29] = GPU3DCommand("POLYGON_ATTR",    1,  1);
    commands[0x2A] = GPU3DCommand("TEXIMAGE_PARAM",  1,  1);
    commands[0x2B] = GPU3DCommand("PLTT_BASE",       1,  1);
    commands[0x30] = GPU3DCommand("DIF_AMB",         1,  4);
    commands[0x31] = GPU3DCommand("SPE_EMI",         1,  4);
    commands[0x32] = GPU3DCommand("LIGHT_VECTOR",    1,  6);
    commands[0x33] = GPU3DCommand("LIGHT_COLOR",     1,  1);
    commands[0x34] = GPU3DCommand("SHININESS",       32, 32);
    commands[0x40] = GPU3DCommand("BEGIN_VTXS",      1,  1);
    commands[0x41] = GPU3DCommand("END_VTXS",        0,  1);
    commands[0x50] = GPU3DCommand("SWAP_BUFFERS",    1,  392);
    commands[0x60] = GPU3DCommand("VIEWPORT",        1,  1);
    commands[0x70] = GPU3DCommand("BOX_TEST",        3,  103);
    commands[0x71] = GPU3DCommand("POS_TEST",        2,  9);
    commands[0x72] = GPU3DCommand("VEC_TEST",        1,  5);

    return commands;
}

immutable GPU3DCommand[256] commands = generate_commands!();

final class GPU3DCommandManager {
    enum State {
        RECEIVING_COMMAND,
        RECEIVING_PARAMETERS
    }

    State state = State.RECEIVING_COMMAND;
    int current_command_id;

    GPU3DCommand[4] command_buffer;
    int command_buffer_length;
    int current_command_index;

    Word[16] command_parameters_buffer;
    int command_parameters_length;
    int command_parameters_remaining;

    void push_command(Word data) {
        final switch (state) {
            case State.RECEIVING_COMMAND:
                command_buffer_length = 0;
                for (int i = 0; i < 4; i++) {
                    if (data.get_byte(i) != 0) {
                        auto command = commands[data.get_byte(i)];
                        if (!command.valid) error_gpu3d("Invalid command! %x", command);

                        command_buffer[command_buffer_length] = command;
                        command_buffer_length++;
                        current_command_index = 0;
                        command_parameters_length = 0;
                    }
                }

                if (command_buffer_length > 0) {
                    command_parameters_remaining = command_buffer[0].num_parameters;
                    state = State.RECEIVING_PARAMETERS;
                }
                break;
            
            case State.RECEIVING_PARAMETERS:
                if (command_parameters_remaining != 0) {
                    command_parameters_buffer[command_parameters_length] = data;
                    command_parameters_remaining--;
                    command_parameters_length++;
                }

                if (command_parameters_remaining == 0) {
                       log_gpu3d("Received well-formed command: %s", command_buffer[current_command_index].name);
                    current_command_index++;

                    if (current_command_index == command_buffer_length) {
                        state = State.RECEIVING_COMMAND;
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
                    }
                        
                    push_command(Word(data));
                }
            ".format(commands[i].name, i));
        }
    }
}