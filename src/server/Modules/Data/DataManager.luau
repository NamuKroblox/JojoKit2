-- DataManager.lua

local Schema = require(script.Parent.Schema)
local ReadWrite = require(script.Parent.ReadWrite)

local DataManager = {}

DataManager.Version = 1

local Layout = {}
local TotalSize = 0

for name, info in Schema do
	local rw = ReadWrite.Types[info.type]

	assert(rw, `Unknown buffer type: {info.type}`)

	Layout[name] = {
		id = info.id,
		offset = TotalSize,
		size = rw.size,
		write = rw.write,
		read = rw.read,
		default = info.default,
	}

	TotalSize += rw.size
end

DataManager.TotalSize = TotalSize

function DataManager.CreateBuffer(): buffer
	local b = buffer.create(TotalSize)

	for name, meta in Layout do
		meta.write(b, meta.offset, meta.default)
	end

	return b
end

function DataManager.Migrate(Data: { number }, fromVersion: number): buffer
	if fromVersion == 1 then
		local b = DataManager.CreateBuffer()
		-- map known offsets from v1 layout manually
		-- e.g. Level was at byte 2 in v1, still byte 2 in v2
		buffer.writeu8(b, 0, Data[2])
		return b
	end
	warn(`[DataManager] Unknown version {fromVersion}, returning fresh buffer`)
	return DataManager.CreateBuffer()
end

function DataManager.Set(Buffer: buffer, key: string, value: number)
	local meta = Layout[key]

	if not meta then
		warn(`[DataManager] Unknown key {key}`)
		return
	end

	meta.write(Buffer, meta.offset, value)
end

function DataManager.Get(Buffer: buffer, key: string): number
	local meta = Layout[key]

	if not meta then
		warn(`[DataManager] Unknown key {key}`)
		return 0
	end

	return meta.read(Buffer, meta.offset)
end

function DataManager.Serialize(Buffer: buffer): { number }
	local bytes = { DataManager.Version }
	for i = 0, TotalSize - 1 do
		bytes[i + 2] = buffer.readu8(Buffer, i)
	end
	return bytes
end

function DataManager.Deserialize(Data: { number }?): buffer
	if not Data or #Data == 0 then
		return DataManager.CreateBuffer()
	end

	if #Data - 1 ~= TotalSize then
		warn("[DataManager] Size mismatch, returning fresh buffer")
		return DataManager.CreateBuffer()
	end

	local version = Data[1]
	if version ~= DataManager.Version then
		return DataManager.Migrate(Data, version)
	end
	local b = buffer.create(TotalSize)
	for i = 2, #Data do
		buffer.writeu8(b, i - 2, Data[i])
	end
	return b
end

function DataManager.Debug(Buffer: buffer)
	print("===== PLAYER DATA =====")

	for name in Layout do
		print(name, DataManager.Get(Buffer, name))
	end
end

return DataManager
