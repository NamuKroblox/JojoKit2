-- ReadWrite.lua

local ReadWrite = {}

ReadWrite.writeu8 = buffer.writeu8
ReadWrite.writeu16 = buffer.writeu16
ReadWrite.writeu32 = buffer.writeu32

ReadWrite.readu8 = buffer.readu8
ReadWrite.readu16 = buffer.readu16
ReadWrite.readu32 = buffer.readu32

ReadWrite.Types = {
	u8 = {
		size = 1,
		write = buffer.writeu8,
		read = buffer.readu8,
	},

	u16 = {
		size = 2,
		write = buffer.writeu16,
		read = buffer.readu16,
	},

	u32 = {
		size = 4,
		write = buffer.writeu32,
		read = buffer.readu32,
	},
}

return ReadWrite
