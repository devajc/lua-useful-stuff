local _aa,aaa,baa,caa=next,type,unpack,select;local daa,_ba=setmetatable,getmetatable
local aba,bba=table.insert,table.sort;local cba,dba=table.remove,table.concat
local _ca,aca,bca=math.randomseed,math.random,math.huge;local cca,dca,_da=math.floor,math.max,math.min;local ada=rawget;local bda=baa
local cda,dda=pairs,ipairs;local __b={}local function a_b(dab,_bb)return dab>_bb end
local function b_b(dab,_bb)return dab<_bb end;local function c_b(dab,_bb,abb)
return(dab<_bb)and _bb or(dab>abb and abb or dab)end
local function d_b(dab,_bb)return _bb and true end;local function _ab(dab)return not dab end;local function aab(dab)local _bb
for abb,bbb in cda(dab)do _bb=(_bb or 0)+1 end;return _bb end
local function bab(dab,_bb,abb,...)local bbb
local cbb=abb or __b.identity;for dbb,_cb in cda(dab)do
if not bbb then bbb=cbb(_cb,...)else local acb=cbb(_cb,...)bbb=
_bb(bbb,acb)and bbb or acb end end;return bbb end;local cab=-1
function __b.each(dab,_bb,...)if not __b.isTable(dab)then return end;for abb,bbb in cda(dab)do
_bb(abb,bbb,...)end end
function __b.eachi(dab,_bb,...)if not __b.isTable(dab)then return end
local abb=__b.sort(__b.select(__b.keys(dab),function(bbb,cbb)return
__b.isInteger(cbb)end))for bbb,cbb in dda(abb)do _bb(cbb,dab[cbb],...)end end
function __b.count(dab,_bb)if __b.isNil(_bb)then return __b.size(dab)end;local abb=0
__b.each(dab,function(bbb,cbb)if
__b.isEqual(cbb,_bb)then abb=abb+1 end end)return abb end
function __b.countf(dab,_bb,...)return __b.count(__b.map(dab,_bb,...),true)end
function __b.cycle(dab,_bb)if _bb<=0 then return end;local abb,bbb;local cbb=0
while true do
return
function()
abb=abb and _aa(dab,abb)or _aa(dab)bbb=not bbb and abb or bbb;if _bb then
cbb=(abb==bbb)and cbb+1 or cbb;if cbb>_bb then return end end
return abb,dab[abb]end end end;function __b.map(dab,_bb,...)local abb={}
for bbb,cbb in cda(dab)do abb[bbb]=_bb(bbb,cbb,...)end;return abb end;function __b.reduce(dab,_bb,abb)
for bbb,cbb in
cda(dab)do abb=not abb and cbb or _bb(abb,cbb)end;return abb end;function __b.reduceRight(dab,_bb,abb)return
__b.reduce(__b.reverse(dab),_bb,abb)end
function __b.mapReduce(dab,_bb,abb)
local bbb={}for cbb,dbb in cda(dab)do bbb[cbb]=not abb and dbb or _bb(abb,dbb)
abb=bbb[cbb]end;return bbb end;function __b.mapReduceRight(dab,_bb,abb)
return __b.mapReduce(__b.reverse(dab),_bb,abb)end
function __b.include(dab,_bb)local abb=
__b.isFunction(_bb)and _bb or __b.isEqual;for bbb,cbb in cda(dab)do if abb(cbb,_bb)then
return true end end;return false end
function __b.detect(dab,_bb)
local abb=__b.isFunction(_bb)and _bb or __b.isEqual;for bbb,cbb in cda(dab)do if abb(cbb,_bb)then return bbb end end end;function __b.contains(dab,_bb)
return __b.detect(dab,_bb)and true or false end
function __b.where(dab,_bb)local abb={}
if __b.isEmpty(_bb)then return{}end;return
__b.select(dab,function(bbb,cbb)
for dbb in cda(_bb)do if _bb[dbb]~=cbb[dbb]then return false end end;return true end)end
function __b.findWhere(dab,_bb)
local abb=__b.detect(dab,function(bbb)for cbb in cda(_bb)do
if _bb[cbb]~=bbb[cbb]then return false end end;return true end)return abb and dab[abb]end
function __b.select(dab,_bb,...)local abb=__b.map(dab,_bb,...)local bbb={}for cbb,dbb in cda(abb)do if dbb then
bbb[#bbb+1]=dab[cbb]end end;return bbb end
function __b.reject(dab,_bb,...)local abb=__b.map(dab,_bb,...)local bbb={}for cbb,dbb in cda(abb)do if not dbb then
bbb[#bbb+1]=dab[cbb]end end;return bbb end;function __b.all(dab,_bb,...)return
( (#__b.select(__b.map(dab,_bb,...),d_b))== (#dab))end
function __b.invoke(dab,_bb,...)
local abb={...}
return
__b.map(dab,function(bbb,cbb)
if __b.isTable(cbb)then
if __b.has(cbb,_bb)then if __b.isCallable(cbb[_bb])then return
cbb[_bb](cbb,bda(abb))else return cbb[_bb]end else if
__b.isCallable(_bb)then return _bb(cbb,bda(abb))end end elseif __b.isCallable(_bb)then return _bb(cbb,bda(abb))end end)end
function __b.pluck(dab,_bb)return
__b.reject(__b.map(dab,function(abb,bbb)return bbb[_bb]end),_ab)end;function __b.max(dab,_bb,...)return bab(dab,a_b,_bb,...)end;function __b.min(dab,_bb,...)return
bab(dab,b_b,_bb,...)end
function __b.shuffle(dab,_bb)if _bb then _ca(_bb)end
local abb={}
__b.each(dab,function(bbb,cbb)local dbb=cca(aca()*bbb)+1;abb[bbb]=abb[dbb]
abb[dbb]=cbb end)return abb end
function __b.same(dab,_bb)
return
__b.all(dab,function(abb,bbb)return __b.include(_bb,bbb)end)and
__b.all(_bb,function(abb,bbb)return __b.include(dab,bbb)end)end;function __b.sort(dab,_bb)bba(dab,_bb)return dab end
function __b.toArray(...)return{...}end
function __b.groupBy(dab,_bb,...)local abb={...}local bbb={}
local cbb=__b.isFunction(_bb)and _bb or
(
__b.isString(_bb)and function(dbb,_cb)return _cb[_bb](_cb,bda(abb))end)if not cbb then return end
__b.each(dab,function(dbb,_cb)local acb=cbb(dbb,_cb)
if bbb[acb]then bbb[acb][#bbb[acb]+
1]=_cb else bbb[acb]={_cb}end end)return bbb end
function __b.countBy(dab,_bb,...)local abb={...}local bbb={}
__b.each(dab,function(cbb,dbb)local _cb=_bb(cbb,dbb,bda(abb))bbb[_cb]=(
bbb[_cb]or 0)+1 end)return bbb end
function __b.size(...)local dab={...}local _bb=dab[1]if __b.isNil(_bb)then return 0 elseif __b.isTable(_bb)then return
aab(dab[1])else return aab(dab)end end;function __b.containsKeys(dab,_bb)
for abb in cda(_bb)do if not dab[abb]then return false end end;return true end
function __b.sameKeys(dab,_bb)
__b.each(dab,function(abb)if
not _bb[abb]then return false end end)
__b.each(_bb,function(abb)if not dab[abb]then return false end end)return true end
function __b.reverse(dab)local _bb={}for i=#dab,1,-1 do _bb[#_bb+1]=dab[i]end;return _bb end
function __b.selectWhile(dab,_bb,...)local abb={}for bbb,cbb in dda(dab)do
if _bb(bbb,cbb,...)then abb[bbb]=cbb else break end end;return abb end
function __b.dropWhile(dab,_bb,...)local abb
for bbb,cbb in dda(dab)do if not _bb(bbb,cbb,...)then abb=bbb;break end end;if __b.isNil(abb)then return{}end;return __b.rest(dab,abb)end
function __b.sortedIndex(dab,_bb,abb,bbb)local cbb=abb or b_b;if bbb then __b.sort(dab,cbb)end;for i=1,#dab do if not
cbb(dab[i],_bb)then return i end end
return#dab+1 end
function __b.indexOf(dab,_bb)for k=1,#dab do if dab[k]==_bb then return k end end end
function __b.lastIndexOf(dab,_bb)local abb=__b.indexOf(__b.reverse(dab),_bb)if abb then return
#dab-abb+1 end end;function __b.add(dab,...)
__b.each({...},function(_bb,abb)aba(dab,1,abb)end)return dab end;function __b.push(dab,...)__b.each({...},function(_bb,abb)
dab[#dab+1]=abb end)
return dab end;function __b.pop(dab)local _bb=dab[1]
cba(dab,1)return _bb end;function __b.unshift(dab)local _bb=dab[#dab]cba(dab)return
_bb end
function __b.removeRange(dab,_bb,abb)local bbb=__b.clone(dab)local cbb,dbb=(_aa(bbb)),
#bbb;if dbb<1 then return bbb end
_bb=c_b(_bb or cbb,cbb,dbb)abb=c_b(abb or dbb,cbb,dbb)if abb<_bb then return bbb end
local _cb=abb-_bb+1;local acb=_bb;while _cb>0 do cba(bbb,acb)_cb=_cb-1 end;return bbb end
function __b.chunk(dab,_bb,...)if not __b.isArray(dab)then return dab end;local abb,bbb,cbb={},0
local dbb=__b.map(dab,_bb,...)
__b.each(dbb,function(_cb,acb)cbb=(cbb==nil)and acb or cbb;bbb=(
(acb~=cbb)and(bbb+1)or bbb)
if not abb[bbb]then abb[bbb]={dab[_cb]}else abb[bbb][
#abb[bbb]+1]=dab[_cb]end;cbb=acb end)return abb end
function __b.slice(dab,_bb,abb)return
__b.select(dab,function(bbb)return
(bbb>= (_bb or _aa(dab))and bbb<= (abb or#dab))end)end;function __b.first(dab,_bb)local abb=_bb or 1
return __b.slice(dab,1,_da(abb,#dab))end
function __b.initial(dab,_bb)
if _bb and _bb<0 then return end;return
__b.slice(dab,1,_bb and#dab- (_da(_bb,#dab))or#dab-1)end;function __b.last(dab,_bb)if _bb and _bb<=0 then return end
return __b.slice(dab,_bb and
#dab-_da(_bb-1,#dab-1)or 2,#dab)end;function __b.rest(dab,_bb)if _bb and
_bb>#dab then return{}end
return __b.slice(dab,
_bb and dca(1,_da(_bb,#dab))or 1,#dab)end;function __b.compact(dab)
return __b.reject(dab,function(_bb,abb)return
not abb end)end
function __b.flatten(dab,_bb)local abb=_bb or false
local bbb;local cbb={}
for dbb,_cb in cda(dab)do
if __b.isTable(_cb)and not abb then
bbb=__b.flatten(_cb)
__b.each(bbb,function(acb,bcb)cbb[#cbb+1]=bcb end)else cbb[#cbb+1]=_cb end end;return cbb end
function __b.difference(dab,_bb)if not _bb then return __b.clone(dab)end;return
__b.select(dab,function(abb,bbb)return not
__b.include(_bb,bbb)end)end
function __b.symmetric_difference(dab,_bb)return
__b.difference(__b.union(dab,_bb),__b.intersection(dab,_bb))end
function __b.uniq(dab,_bb,abb,...)
local bbb=abb and __b.map(dab,abb,...)or dab;local cbb={}
if not _bb then for dbb,_cb in dda(bbb)do
if not __b.include(cbb,_cb)then cbb[#cbb+1]=_cb end end;return cbb end;cbb[#cbb+1]=bbb[1]for i=2,#bbb do if bbb[i]~=cbb[#cbb]then
cbb[#cbb+1]=bbb[i]end end;return cbb end
function __b.union(...)return __b.uniq(__b.flatten({...}))end
function __b.intersection(dab,...)local _bb={...}local abb={}
for bbb,cbb in dda(dab)do if
__b.all(_bb,function(dbb,_cb)return __b.include(_cb,cbb)end)then aba(abb,cbb)end end;return abb end
function __b.zip(...)local dab={...}
local _bb=__b.max(__b.map(dab,function(bbb,cbb)return#cbb end))local abb={}for i=1,_bb do abb[i]=__b.pluck(dab,i)end;return abb end
function __b.append(dab,_bb)local abb={}for bbb,cbb in dda(dab)do abb[bbb]=cbb end;for bbb,cbb in dda(_bb)do
abb[#abb+1]=cbb end;return abb end
function __b.range(...)local dab={...}local _bb,abb,bbb
if#dab==0 then return{}elseif#dab==1 then abb,_bb,bbb=dab[1],0,1 elseif#dab==2 then
_bb,abb,bbb=dab[1],dab[2],1 elseif#dab==3 then _bb,abb,bbb=dab[1],dab[2],dab[3]end;if(bbb and bbb==0)then return{}end;local cbb={}
local dbb=dca(cca((abb-_bb)/bbb),0)for i=1,dbb do cbb[#cbb+1]=_bb+bbb*i end;if#cbb>0 then
aba(cbb,1,_bb)end;return cbb end;function __b.invert(dab)local _bb={}
__b.each(dab,function(abb,bbb)_bb[bbb]=abb end)return _bb end
function __b.concat(dab,_bb,abb,bbb)
local cbb=__b.map(dab,function(dbb,_cb)return
tostring(_cb)end)return dba(cbb,_bb,abb,bbb)end;function __b.identity(dab)return dab end
function __b.once(dab)local _bb=0;local abb={}return
function(...)_bb=_bb+1;if _bb<=1 then
abb={...}end;return dab(bda(abb))end end
function __b.memoize(dab,_bb)local abb=daa({},{__mode='kv'})
local bbb=_bb or __b.identity
return function(...)local cbb=bbb(...)local dbb=abb[cbb]
if not dbb then abb[cbb]=dab(...)end;return abb[cbb]end end
function __b.after(dab,_bb)local abb,bbb=_bb,0;return
function(...)bbb=bbb+1;if bbb>=abb then return dab(...)end end end
function __b.compose(...)local dab=__b.reverse{...}return
function(...)local _bb;for abb,bbb in cda(dab)do _bb=_bb and bbb(_bb)or
bbb(...)end;return _bb end end
function __b.wrap(dab,_bb)return function(...)return _bb(dab,...)end end
function __b.times(dab,_bb,...)local abb={}for i=1,dab do abb[i]=_bb(i,...)end;return abb end
function __b.bind(dab,_bb)return function(...)return dab(_bb,...)end end
function __b.bindn(dab,...)local _bb={...}return function(...)
return dab(bda(__b.append(_bb,{...})))end end
function __b.uniqueId(dab,...)cab=cab+1
if dab then if __b.isString(dab)then return dab:format(cab)elseif
__b.isFunction(dab)then return dab(cab,...)end end;return cab end;function __b.keys(dab)local _bb={}
__b.each(dab,function(abb)_bb[#_bb+1]=abb end)return _bb end;function __b.values(dab)local _bb={}
__b.each(dab,function(abb,bbb)_bb[
#_bb+1]=bbb end)return _bb end;function __b.paired(dab)local _bb={}
__b.each(dab,function(abb,bbb)_bb[
#_bb+1]={abb,bbb}end)return _bb end
function __b.extend(dab,...)
local _bb={...}
__b.each(_bb,function(abb,bbb)if __b.isTable(bbb)then
__b.each(bbb,function(cbb,dbb)dab[cbb]=dbb end)end end)return dab end
function __b.functions(dab)if not dab then return
__b.sort(__b.push(__b.keys(__b),'chain','value','import'))end
local _bb={}
__b.each(dab,function(bbb,cbb)if __b.isFunction(cbb)then _bb[#_bb+1]=bbb end end)local abb=_ba(dab)if abb and abb.__index then
local bbb=__b.functions(abb.__index)
__b.each(bbb,function(cbb,dbb)_bb[#_bb+1]=dbb end)end
return __b.sort(_bb)end
function __b.clone(dab,_bb)if not __b.isTable(dab)then return dab end;local abb={}
__b.each(dab,function(bbb,cbb)if
__b.isTable(cbb)then
if not _bb then abb[bbb]=__b.clone(cbb,_bb)else abb[bbb]=cbb end else abb[bbb]=cbb end end)return abb end;function __b.tap(dab,_bb,...)_bb(dab,...)return dab end;function __b.has(dab,_bb)return
dab[_bb]~=nil end
function __b.pick(dab,...)local _bb=__b.flatten{...}
local abb={}
__b.each(_bb,function(bbb,cbb)if dab[cbb]then abb[cbb]=dab[cbb]end end)return abb end
function __b.omit(dab,...)local _bb=__b.flatten{...}local abb={}
__b.each(dab,function(bbb,cbb)if
not __b.include(_bb,bbb)then abb[bbb]=cbb end end)return abb end;function __b.template(dab,_bb)
__b.each(_bb,function(abb,bbb)if not dab[abb]then dab[abb]=bbb end end)return dab end
function __b.isEqual(dab,_bb,abb)
local bbb=aaa(dab)local cbb=aaa(_bb)if bbb~=cbb then return false end
if bbb~='table'then return(dab==_bb)end;local dbb=_ba(dab)local _cb=_ba(_bb)
if abb then if
dbb or _cb and dbb.__eq or _cb.__eq then return(dab==_bb)end end
if __b.size(dab)~=__b.size(_bb)then return false end
for acb,bcb in cda(dab)do local ccb=_bb[acb]if
__b.isNil(ccb)or not __b.isEqual(bcb,ccb,abb)then return false end end
for acb,bcb in cda(_bb)do local ccb=dab[acb]if __b.isNil(ccb)then return false end end;return true end
function __b.result(dab,_bb,...)
if dab[_bb]then if __b.isCallable(dab[_bb])then return dab[_bb](dab,...)else return
dab[_bb]end end;if __b.isCallable(_bb)then return _bb(dab,...)end end;function __b.isTable(dab)return aaa(dab)=='table'end
function __b.isCallable(dab)return
(
__b.isFunction(dab)or
(__b.isTable(dab)and _ba(dab)and _ba(dab).__call~=nil)or false)end;function __b.isArray(dab)if not __b.isTable(dab)then return false end;return
aab(dab)==#dab end
function __b.isEmpty(dab)if
__b.isString(dab)then return#dab==0 end;if __b.isTable(dab)then
return _aa(dab)==nil end;return true end;function __b.isString(dab)return aaa(dab)=='string'end;function __b.isFunction(dab)return
aaa(dab)=='function'end;function __b.isNil(dab)
return dab==nil end
function __b.isFinite(dab)
if not __b.isNumber(dab)then return false end;return dab>-bca and dab<bca end;function __b.isNumber(dab)return aaa(dab)=='number'end;function __b.isNaN(dab)return
__b.isNumber(dab)and dab~=dab end;function __b.isBoolean(dab)return
aaa(dab)=='boolean'end
function __b.isInteger(dab)return
__b.isNumber(dab)and cca(dab)==dab end
do local dab={}local _bb={}_bb.__index=dab;local function abb(bbb)local cbb={_value=bbb,_wrapped=true}
return daa(cbb,_bb)end
daa(_bb,{__call=function(bbb,cbb)return abb(cbb)end,__index=function(bbb,cbb,...)return
dab[cbb]end})function _bb.chain(bbb)return abb(bbb)end
function _bb:value()return self._value end;dab.chain,dab.value=_bb.chain,_bb.value
if ada(_G,'MOSES_ALIASES')then
__b.forEach=__b.each;__b.forEachi=__b.eachi;__b.loop=__b.cycle;__b.collect=__b.map
__b.inject=__b.reduce;__b.foldl=__b.reduce;__b.injectr=__b.reduceRight
__b.foldr=__b.reduceRight;__b.mapr=__b.mapReduce;__b.maprr=__b.mapReduceRight
__b.any=__b.include;__b.some=__b.include;__b.find=__b.detect;__b.filter=__b.select
__b.discard=__b.reject;__b.every=__b.all;__b.takeWhile=__b.selectWhile
__b.rejectWhile=__b.dropWhile;__b.shift=__b.pop;__b.rmRange=__b.removeRange
__b.chop=__b.removeRange;__b.head=__b.first;__b.take=__b.first;__b.tail=__b.rest
__b.skip=__b.last;__b.without=__b.difference;__b.diff=__b.difference
__b.symdiff=__b.symmetric_difference;__b.unique=__b.uniq;__b.mirror=__b.invert;__b.join=__b.concat
__b.cache=__b.memoize;__b.uId=__b.uniqueId;__b.methods=__b.functions;__b.choose=__b.pick
__b.drop=__b.omit;__b.defaults=__b.template end
for bbb,cbb in cda(__b)do
dab[bbb]=function(dbb,...)
local _cb=__b.isTable(dbb)and dbb._wrapped or false
if _cb then local acb=dbb._value;local bcb=cbb(acb,...)return abb(bcb)else return cbb(dbb,...)end end end
dab.import=function(bbb,cbb)local dbb={}bbb=bbb or _G
__b.each(dab,function(_cb,acb)if cbb then
if not ada(bbb,_cb)then dbb[_cb]=acb end else dbb[_cb]=acb end end)return __b.extend(bbb or _G,dbb)end;return _bb end