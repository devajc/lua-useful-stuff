local ffi = require "ffi"

local MemoryStream = require "MemoryStream"

local function CreatePreambleChunk(preamble)
	local mstream = MemoryStream.new()
	local success = preamble:WritePreamble(mstream)
	len = mstream:GetPosition()
	mstream:Seek(0)
	local chunk = mstream:ReadString(len)

	return chunk
end

local function WriteChunk(stream, chunk, wrap)
	--print("-- WriteChunk()", wrap)

	if not chunk then
		if wrap then
			stream:WriteString(string.format("%x\r\n", 5))
			WriteChunk(stream, nil, false)
			stream:WriteString("\r\n")

			WriteChunk(stream, nil, false)
		else
			stream:WriteString("0\r\n\r\n");
		end
	else
		--print("-- CHUNK SIZE: ", #chunk)
		local chunksize = string.format("%x\r\n", #chunk)
		if wrap then
			stream:WriteString(string.format("%x\r\n", #chunk+#chunksize + 2))
			WriteChunk(stream, chunk, false)
			stream:WriteString("\r\n")
		else
			stream:WriteString(chunksize)
			stream:WriteString(chunk)
			stream:WriteString("\r\n")
		end
	end
end

local function ReadSingleChunk(stream)
	--print("-- HttpChunkIterator - READ CHUNK");

	local blankline
	local err

	-- Read chunk size
	local chunksizeline, err = stream:ReadLine(1024)

	if not chunksizeline then
		return nil, err
	end

	local chunksize = tonumber(chunksizeline, 16)

--print(string.format("\n-- FIRST CHUNK LINE SIZE: '%s', %d",chunksizeline, chunksize));

assert(chunksize, "expected a valid number ", chunksizeline);
--print("-- ReadSingleChunk(), CHUNK SIZE: ", chunksize);

	-- If there's a zero sized chunk, we're done
	-- just read past the following blank line
	if chunksize == 0 then
		-- Read one more blank line chunk
		blankline, err = stream:ReadLine(1024);
		if not blankline or blankline == "" then
			return nil, "eof"
		end

		return nil, err
	end

	local buff = ffi.new("uint8_t[?]", chunksize);

	bytesread, err = stream:ReadBytes(buff, chunksize);
--print("-- ReadSingleChunk(), bytesread: ", bytesread, err)

	if not bytesread then
		return nil, err
	end

	if bytesread == 0 then
		return nil, "eof"
	end

	-- Read past the blank line
	blankline, err = stream:ReadLine(1024);
	--if not blankline then
	--	return nil, "eof"
	--end

	return ffi.string(buff, bytesread)
end




local function ReadChunks(response)
	local input = response.DataStream
	local transferencoding = response:GetHeader("transfer-encoding");
	local ischunked = false;
	local contentLength = response:GetHeader("content-length")
	local connection = response:GetHeader("connection")
	if connection then
		connection = connection:lower();
	end

	local returnedLast = false


	if transferencoding and transferencoding:lower() == "chunked" then
		ischunked = true;
	end
	
	--print("HttpChunkIterator.new() IsChunked: ", ischunked)
	--print("--contentLength: ", contentLength);
	--print("--connection: ", connection);

	local function closure()
		local chunkbuffer;

		if returnedLast then
			return nil
		end

		if ischunked then
			local chunk, size = ReadSingleChunk(input)

			if not chunk then
				--print("##NO CHUNK READ!!");
				return nil
			end

			return chunk, size
		elseif contentLength then
			local length = tonumber(contentLength)
			--print("-- HTTPChunked: Content-Length: ", length);
			local chunk
			if length > 0 then
				chunk = input:ReadString(length)
			end
			returnedLast = true

			return chunk, length
		elseif connection and connection == "close" then
			--print("NOT CHUNKED, NOR CONTENT-LENGTH")
			-- retrieve a chunk of 8k in size
			-- or whatever we can read
			-- and return that
			local chunksize = 1024*8
			return input:ReadString(chunksize)
		else
			--print("-- UNKNOWN CONTENT SIZE");
			-- assume 'connection:close'
			local chunksize = 1024*8
			return input:ReadString(chunksize)			
		end

		return nil
	end

	return closure
end

return {
	ReadSingleChunk = ReadSingleChunk,
	ReadChunks = ReadChunks,
	WriteChunk = WriteChunk,
	CreatePreambleChunk = CreatePreambleChunk,
}

