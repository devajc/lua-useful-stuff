local ffi = require "ffi"
local C = ffi.C

local bit = require "bit"
local bor = bit.bor
local rshift = bit.rshift
local lshift = bit.lshift

local memutils = require "memutils"



-- round up to the nearest
-- power of 2
local function kv_roundup32(x) 
	x = x - 1; 
	x = bor(x,rshift(x,1)); 
	x = bor(x,rshift(x,2)); 
	x = bor(x,rshift(x,4)); 
	x = bor(x,rshift(x,8)); 
	x = bor(x,rshift(x,16)); 
	x = x + 1;
	
	return x
end


local Vector = {}
local Vector_mt = {
	__index = Vector,
}
			
Vector.new = function(elemtype, capacity)

	capacity = capacity or 0

	local obj = {
		ElementType = ffi.typeof(elemtype),
		n = 0,
		Capacity = capacity,
		Data = nil,
	}
	setmetatable(obj, Vector_mt);
	
	return obj
end

function Vector:Free()
	if self.Data ~= nil then
		ffi.C.free(self.Data);
	end
end

-- Maximumm number of elements
Vector.Max = function(self)
	return self.Capacity;
end

-- Current number of elements in vector
Vector.Size = function(self)
	return self.n;
end

Vector.Realloc = function(self, nelems)
	if nelems == 0 then
		if self.Data ~= nil then
			ffi.C.free(self.Data)
			self.Data = nil
		end
		return nil
	end
	
	local newdata = ffi.C.malloc(ffi.sizeof(self.ElementType)* nelems);

	-- copy existing over to new one
	local maxCopy = math.min(nelems, self.n);
	ffi.copy(newdata, ffi.cast("const uint8_t *",self.Data), ffi.sizeof(self.ElementType) * maxCopy);
	local typeptr = ffi.typeof("$ *", self.ElementType);
	--print("Type PTR: ", typeptr);
	
	-- free old data
	ffi.C.free(self.Data);
	
	self.Data = ffi.cast(typeptr,newdata);	
end

-- access an element
-- perform bounds checking and resizing
Vector.a = function(v, i) 
	if v.Capacity <= i then						
		v.Capacity = i + 1; 
		v.n = i + 1;
		v.Capacity = kv_roundup32(v.Capacity) 
		self:Realloc(v.Capacity) 
	else
		if v.n <= i then 
			v.n = i			
		end
	end
			
	return v.Data[i]
end	  

-- Access without bounds checking
Vector.Elements = function(self)
	local index = -1;
	
	local clojure = function()
		index = index + 1;
		if index < self.n then
			return self.Data[index];
		end
		return nil
	end
	
	return clojure
end

Vector.A = function(self, i)
	return self.Data[i];
end

Vector.Resize = function(self, s) 
	self.Capacity = s; 
	self:Realloc(self.Data, self.Capacity)
end
		
Vector.Copy = function(self, v0)
	-- If we're too small, then increase
	-- size to match
	if (self.Capacity < v0.n) then
		self:Resize(v0.n);
	end
			
	self.n = v0.n;									
	ffi.copy(self.Data, v0.Data, ffi.sizeof(self.Data[0]) * v0.n);		
end
		
-- pop, without bounds checking
Vector.Pop = function(self)
	self.n = self.n-1;
	return self.Data[self.n]
end

Vector.Push = function(v, x) 
	if (v.n == v.Capacity) then	
		if v.Capacity > 0 then
			v.Capacity = lshift(v.Capacity, 1)
		else
			v.Capacity = 2;
		end
		v:Realloc(v.Capacity);
	end															
			
	v.Data[v.n] = x;
	v.n = v.n + 1;
end
		
Vector.Pushp = function(v) 
	if (v.n == v.Capacity) then
		if v.Capacity > 0 then
			v.Capacity = lshift(v.Capacity, 1)
		else
			v.Capacity = 2
		end
		v:Realloc(v.Capacity)	
	end
				
	v.n = v.n + 1
	return v.Data + v.n-1
end

return Vector;

