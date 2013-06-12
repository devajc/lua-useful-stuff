-- http://www.corsix.org/lua/reflect/api.html
local ffi = require("ffi");
local reflect = require("reflect");



structForm = {}
setmetatable(structForm, {
	__call = function(self, atype)
		return self:new(atype);
	end,
})

structForm.new = function(self, atype)

print("WHAT: ", atype.what);

	local func = structForm[atype.what];
	if not func then
		return false, "no function found"
	end

	local str, err = func(atype);
	
	return str, err;
end

structForm.field = function(ref)
	return string.format("%s  %s", structForm(ref.type), ref.name);
end

structForm.float = function(ref)
	if ref.size == 4 then
		return "float";
	elseif ref.size == 8 then
		return "double";
	end

	return false, "unknown float size";
end

structForm.func = function(ref)

	local str = structForm(ref.return_type);
	str = str..' '..ref.name;
	str = str..'(';
	for i=1,ref.nargs do
		if i>1 then
			str = str..', ';
		end

		str = str..structForm(ref:argument(i));
		--print("ARG: ", ref:argument(i));
	end
	str = str..');';

	return str;
end

structForm.int = function(ref)
	local str="";
	
	if ref.const then
		str = str.."const ";
	end
	
	if ref.bool then
		return str..'bool';
	end

	if ref.unsigned then
		str = str.."u";
	end
	

	return str..string.format("int%d_t", ref.size*8);
end

structForm.ptr = function(ref)
	local str = structForm(ref.element_type);
	if not str then
		return false;
	end

	return str..' *';
end

structForm.struct = function(ref)
	local res = {};
	table.insert(res, string.format("typedef struct %s {\n", ref.name));
	for member in ref:members() do
		local str = "  "..structForm(member)..';\n';
		if str then
			table.insert(res, str);
		end
	end
	table.insert(res, string.format("} %s;\n", ref.name));

	return table.concat(res);
end

structForm.void = function(ref)
	return 'void';
end


local function printType(atype)
	local refType = reflect.typeof(atype);
	local str = structForm(refType);
	print(str);
end


require("WTypes");

ffi.cdef[[
typedef struct _Foo {
	int x;
	int y;	

	uint32_t r;
	float g;
	double b;
} Foo;

int (* PFNFooFuncPROC)(int x, int y);

BOOL
GetConsoleMode(HANDLE hConsoleHandle, LPDWORD lpMode);


]]


--printType(ffi.typeof("Foo"));
printType(ffi.C["GetConsoleMode"]);
--printType(ffi.typeof("PFNFooFuncPROC"));

