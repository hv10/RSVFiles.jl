module RSVFiles

using FileIO

# based upon Stenways RSV-Challenge Repositories code for Julia
# see [Stenway/RSV-Challenge -> rsv.jl](https://github.com/Stenway/RSV-Challenge/blob/main/Julia/rsv.jl)

const utf8ByteClassLookup = [
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
	4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
	4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
	0, 0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
	5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
	6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 7, 7,
	9, 10, 10, 10, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
]
const utf8StateTransitionLookup = [
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 2, 3, 5, 4, 6, 7, 8,
	0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 5, 5, 5, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0
]

function isValidUtf8(bytes::Vector{UInt8})::Bool
	lastState = 1
	for i=1:length(bytes)
		currentByte = UInt8(bytes[i])
		currentByteClass = utf8ByteClassLookup[Int(currentByte) + 1]
		newStateLookupIndex = lastState * 12 + currentByteClass
		lastState = utf8StateTransitionLookup[newStateLookupIndex + 1]
		if lastState == 0
			return false
		end
	end
	return lastState == 1
end

# ----------------------------------------------------------------------

function encodeRsv(rows::Vector{Vector})::Vector{UInt8}
	bytes = Vector{UInt8}()
	for row in rows
		for value in row
			if isnothing(value) 
				push!(bytes, 0xFE)
			else
				rval = string(value) # we convert the object to string not repr
				if length(rval) > 0
					valueBytes = Vector{UInt8}(rval)
					if !isValidUtf8(valueBytes)
						throw(DomainError("Invalid string value"))
					end
					append!(bytes, valueBytes)
				end
			end
			push!(bytes, 0xFF)
		end
		push!(bytes, 0xFD)
	end
	return bytes
end

function decodeRsv(bytes::Vector{UInt8})::Vector{Vector{Union{String, Nothing}}}
	if !isempty(bytes) && bytes[end] != 0xFD
		throw(DomainError("Incomplete RSV document"))
	end
	result = Vector{Vector{Union{String, Nothing}}}()
	currentRow = Vector{Union{String, Nothing}}()
	valueStartIndex = 1
	for i in eachindex(bytes)
		if bytes[i] == 0xFF
			length = i-valueStartIndex
			if length == 0
				push!(currentRow, "")
			elseif length == 1 && bytes[valueStartIndex] == 0xFE
				push!(currentRow, nothing)
			else
				valueBytes = bytes[valueStartIndex:valueStartIndex+length-1]
				if !isValidUtf8(valueBytes)
					@show valueBytes
					throw(DomainError("Invalid string value"))
				end
				push!(currentRow, String(valueBytes))
			end
			valueStartIndex = i+1
		elseif bytes[i] == 0xFD
			if i > 0 && valueStartIndex != i
				throw(DomainError("Incomplete RSV row"))
			end
			push!(result, copy(currentRow))
			empty!(currentRow)
			valueStartIndex = i+1
		end
	end
	return result
end

# ----------------------------------------------------------------------

const rsvByteClassLookup = [
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
	4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
	4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
	0, 0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
	5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
	6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 7, 7,
	9, 10, 10, 10, 11, 0, 0, 0, 0, 0, 0, 0, 0, 12, 13, 14
]
const rsvStateTransitionLookup = [
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 2, 0, 0, 0, 3, 4, 6, 5, 7, 8, 9, 1, 10, 11,
	0, 2, 0, 0, 0, 3, 4, 6, 5, 7, 8, 9, 0, 0, 11,
	0, 0, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 6, 6, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11,
	0, 2, 0, 0, 0, 3, 4, 6, 5, 7, 8, 9, 1, 10, 11
]

function isValidRsv(bytes::Vector{UInt8})::Bool
	lastState = 1
	for i=1:length(bytes)
		currentByte = UInt8(bytes[i])
		currentByteClass = rsvByteClassLookup[Int(currentByte) + 1]
		newStateLookupIndex = lastState * 15 + currentByteClass
		lastState = rsvStateTransitionLookup[newStateLookupIndex + 1]
		if lastState == 0
			return false
		end
	end
	return lastState == 1
end

# ----------------------------------------------------------------------


function openFileToAppend(filePath::String)
	try
		return open(filePath, "r+")
	catch e
		return open(filePath, "w+")
	end
end

function appendRsv(rows::Vector{Vector{Union{String, Nothing}}}, filePath::String, continueLastRow::Bool)
	file = openFileToAppend(filePath)
	fileSize = stat(filePath).size
	if continueLastRow && fileSize > 0
		seek(file, fileSize - 1)
		lastByte = UInt8[1]
		readbytes!(file, lastByte, 1)
		if lastByte[1] != 0xFD
			close(file)
			throw(DomainError("Incomplete RSV document"))
		end
		if length(rows) == 0
			close(file)
			return
		end
		seek(file, fileSize - 1)
	else
		seek(file, fileSize)
	end
	bytes = encodeRsv(rows)
	write(file, bytes)
	close(file)
end

#-----------------------------------------------------------------------

function load(f::File{format"RSV"})::Vector{Vector{Union{String, Nothing}}}
	open(f) do s
		bytes = read(s)
		return decodeRsv(bytes)
	end
end

function save(f::File{format"RSV"}, data)
	encodedRows = encodeRsv(data)
	open(f, "w") do file
		write(file, encodedRows)
	end
end

add_format(
	format"RSV",(),
	".rsv", [RSVFiles]
)


end # module RSVFiles
