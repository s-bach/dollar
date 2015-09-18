'''#############################################################v1''
#
#                     The dollar function ($)
#                       by Christoph Bach (C)
#
# Usage:
	 do $ () ->
		 console.log 'Wer a sagt muss auch...'
		 yield $ (cb) -> setTimeout cb, 1000
		 console.log '... b sagen!'
#
''###############################################################'''

assert = require 'assert'

GeneratorFunction = (->yield 0).constructor if !GeneratorFunction?
Generator = (do->yield 0).constructor if !Generator?

isType1 = (obj) ->
	obj &&
		0 <= Array::indexOf.call arguments, obj.constructor, 1

isType = (obj) ->
	obj &&
		0 <= (i = Array::indexOf.call arguments, obj.constructor, 1) &&
			arguments[i]:: == Object.getPrototypeOf obj

class $Callable extends Function
	constructor: (t) ->
		f = () -> f.call arguments
		Object.setPrototypeOf f, t::
		return f

class $Generator extends Function
	call: ([err, val]) ->
		assert isType1 @g, Generator # internal error
		try
			{value, done} = if err? then @g.throw err else @g.next val
		catch e
			@return e
			return
		if done
			@return null, value
			return
		unless typeof value == 'function' && isType1 value, $
			@call new Error "Missing dollar while using yield."
			return
		try
			value @
		catch e
			throw e if @done
			@call e
		return

	return: (e, v) ->
		if @cb
			@done = true
			@cb e, v
		else if e?
			throw e

class $ extends Function
	constructor: (fn) ->
		unless typeof fn == 'function'
			throw new Error 'The first parameter must be callable.'
		unless isType fn, Function, GeneratorFunction
			throw new Error 'The first parameter must be a Function or a GeneratorFunction.'
		re = new $Callable $
		re.args1 = arguments
		re.exec = re.new if isType1 @, $
		return re

	new: (args) ->
		new (Function::bind.apply args[0], args)

	exec: (args) ->
		Function::call.apply args[0], args

	call: (args2) ->
		args = Array @args1.length + args2.length
		args[i] = @args1[i] for v, i in @args1
		args[@args1.length + i] = args2[i] for v, i in args2
		if args[0].constructor == GeneratorFunction
			fn = new $Callable $Generator
			if fn.cb = args2[args2.length - 1]
				unless typeof fn.cb == 'function'
					throw new Error 'The last parameter must be a callable callback.'
				args.length--
			fn.g = @exec args
			do fn
			return
		@exec args
		return

module.exports = {$}