_G.Class = require '30log'

context('Derivation (Inheritance)',function()
  local Window
    
  before(function()
    Window = Class { width = 100, height = 100 }
    function Window:setSize(w,h) self.width, self.height = w,h end
  end)
  
  context('Class can be derived from a superclass',function()
  
    test('Via "extends()" method',function()
      local Frame = Window:extends()
      assert_equal(type(Frame),'table')
    end)
  
    test('With extra-arguments passed to method "extends()" as a table',function()
      local Frame = Window:extends {ID = 1}
      assert_equal(Frame.ID,1)
      assert_equal(Frame.width,100)
      assert_equal(Frame.height,100)
    end)
    
  end)
  
  context('A derived class still points to its superclass',function()
  
    test('Via its "super" key',function()
      local Frame = Window:extends()
      assert_equal(Frame.super,Window)
    end)
    
    test('Via "getmetatable()" function',function()
      local Frame = Window:extends()
      assert_equal(getmetatable(Frame),Window)  
    end)    
    
  end)
  
  context('A derived class',function()
  
    test('can instantiate objects',function()
      local Frame = Window:extends()
      function Frame:setSize(size) self.width, self.height = size,size end
      local app = Frame()
      local app2 = Frame:new()
      assert_equal(type(app),'table')  
      assert_equal(type(app2),'table')
    end)  
    
    test('shares its superclass attributes',function()
      local Frame = Window:extends()
      assert_equal(Frame.width,100)  
      assert_equal(Frame.height,100)  
    end)
    
    test('shares its superclass methods',function()
      local Frame = Window:extends()
      Frame:setSize(15,15)
      assert_equal(type(Frame.setSize),'function')  
      assert_equal(Frame.width,15)  
      assert_equal(Frame.height,15)  
    end)
    
    test('can reimplement its superclass methods',function()
      local Frame = Window:extends()
      function Frame:setSize(size) self.width, self.height = size,size end
      Frame:setSize(30)
      assert_equal(Frame.width,30)  
      assert_equal(Frame.height,30) 
    end)
  
    test('Yet, it still has access to the original superclass method',function()
      local Frame = Window:extends()
      function Frame:setSize(size) self.width, self.height = size,size end
      Frame.super.setSize(Frame,50,55)
      assert_equal(Frame.width,50)  
      assert_equal(Frame.height,55) 
    end)     
    
  end)
  
  context('In a single inheritance model', function()
    local A, B, C, D
    before(function()
      A = Class()
      function A.__init(instance,a)
        instance.a = a
      end
      B = A:extends()
      function B.__init(instance, a, b)
        B.super.__init(instance, a)
        instance.b = b
      end
      C = B:extends()
      function C.__init(instance, a, b, c)
        C.super.__init(instance,a, b)
        instance.c = c
      end
      D = C:extends()
      function D.__init(instance, a, b, c, d)
        D.super.__init(instance,a, b, c)
        instance.d = d
      end
    end)
      
    test('__init() class constructor can chain', function()
      local a = A(1)
      local b = B(1,2)
      local c = C(1,2,3)
      local d = D(1,2,3,4)
      assert_equal(a.a,1)
      assert_equal(b.a,1)
      assert_equal(b.b,2)
      assert_equal(c.a,1)
      assert_equal(c.b,2)
      assert_equal(c.c,3)
      assert_equal(d.a,1)
      assert_equal(d.b,2)
      assert_equal(d.c,3)
      assert_equal(d.d,4)
    end)
    
  end)
  
 end)