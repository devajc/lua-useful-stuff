TINN
====

As an acronym, TINN could stand for many things:
*	Test Infrastructure for Network Nodes
*	Tcp IP Networking Nodule

One thing is for sure though  
	
	TINN Is Not Node


TINN is like a Swiss army knife for coding on the Windows platform.  With TINN, you can create any number
of interesting applications from somewhat scalable web services to collaborative video games.

TINN is based on the LuaJIT compiler.  As such, the programs you write for TINN are actually normal looking LuaJIT scripts.

Included in the box with TINN are some basic modules  
*	lpeg - for interesting text parsing and manipulation  
*	zlib - because you'll want to compress some stuff  
*	networking - because you'll want to talk to other things  
*	win32 - User32, GDI32, Kernel32, BCrypt, so you can easily put Windows based stuff together

As TINN is focused on Windows development, there is quite a lot available in the windows bindings.
There is the concept of api sets, which reflect the layering of APIs since Windows 7.  Within the api sets
you will find items such as ldap, sspi, libraryloader, processthreads, security_base, etc.

In addition to the basics, TINN includes a fairly simple, but useful, event scheduler.  
This scheduler supports a cooperative multi-tasking networking module, as well as a general 
model for seamlessly dealing with cooperative processing.  
  
Here is a very simple example of getting the IP address of the networking interface:  

`local net = require("Network")()`  
`print(net:GetLocalInterface())`  
  
  
The general philosophy behind TINN is to make fairly mundane things very easy, make very hard things very approachable, and keep really easy things really easy.  
  

Building TINN
-------------

Within the src directory, you will find almost everything you need to build TINN.  As TINN is specifically
meant for Windows, there is a msvcbuild.bat file.  If you've ever compiled the LuaJIT project, this will look
very familiar because it's the same file, with some specific modifications.
*	Bring up a Visual Studio command prompt  
*	cd to the src directory  
*	run the msvcbuild.bat script  

You will end up with a tinn.exe file.  To use TINN, you will need the lua51.dll, and zlib1.dll.  These are provided in the root directory of the project.  Simply copy these to some directory, along with the tinn.exe and you can then run tinn.  The root directory also contains the files msvcr100.dll and msvcp100.dll.  These are 
the C runtime library files for Visual Studio 10.0.  If they're not already on your machine, you should include them as well.

Using TINN
----------

Run the tinn.exe program, and pass it the name of the script you want to run:

tinn.exe test_network.lua


TINN introduces a couple of fairly useful constructs.  'include' and 'use'.

the "require()" function is native the the Lua language.  'include' builds upon this by making a global variable with
the same name as the required module.

include('dsrole')

This will make available a global variable with the name 'dsrole'.  This gives you a ready handle on the module.  Really
it's different than simply calling 'require' where it is needed, as the system also maintains a handle on the module.

use('dsrole')

The 'use()' function is slightly different.  It will also perform a 'require' on the module, but it will also make global anything that is returned from the call.  This assumes that what is returned from the call is a table.  This is useful for
quickly turning a module into a set of globally accessible functions.  So, if you have a module that looks like the following:

-- dsrole.lua
local dsrole = {
    DsRoleFreeMemory = Lib.DsRoleFreeMemory,
    DsRoleGetPrimaryDomainInformation = Lib.DsRoleGetPrimaryDomainInformation,    
};

return dsrole

If you then call:

use("dsrole")

The functions, DsRoleFreeMemory, and DsRoleGetPrimaryDomainInformation will become functions in the global namespace.
this is very convenient from the programmer's perspective as it make coding look very similar to what you would do 
if you were simply programming in 'C' using these APIs.  At the same time, you are not forced to use this mechanism.
If you prefer to maintain functions in their modular scoped spaces, then you can simply use the regular 'require' function.

Examples
--------
There are a growing number of examples to be found in the TINNSnips project:  
https://github.com/Wiladams/TINNSnips  



