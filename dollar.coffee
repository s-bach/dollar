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

c = () ->
	g = (qq) ->
		try
			{value, done} = do qq
		catch e
			throw e unless f.cb?
			f.done = true
			f.cb e
			return
		if done
			if typeof f.cb == 'function'
				f.done = true
				f.cb null, value
			return
		unless typeof value == 'function'
			if typeof value.then == 'function' # Promise support
				promiseDone = false
				reject_fulfill = (a) ->
					return if promiseDone
					promiseDone = true
					try
						g a
					catch e
						f.done = true
						setImmediate () -> throw e
				fulfill = (val) -> reject_fulfill () -> f.g.next val
				reject = (err) -> reject_fulfill () -> f.g.throw err
				try
					value.then fulfill, reject
				catch e
					reject e
				return
			console.log "Missing dollar while using yield."
			f new Error "Missing dollar while using yield."
			return
		if value.constructor == GeneratorFunction
			value = $ value
		try
			f.re = value f
		catch err
			throw err if f.done
			g () -> f.g.throw err
		return
	f = (err, val) -> g if err? then () -> f.g.throw err else () -> f.g.next val || f.re

$ = () ->
	args1 = Array::slice.call arguments, 0
	#args1 = arguments
	throw new Error 'The first parameter must be callable.' if typeof args1[0] != 'function'
	throw new Error 'The first parameter must be a Function or a GeneratorFunction.' unless args1[0].constructor in [Function, GeneratorFunction]
	a = (args2) ->
		args = Array args1.length + args2.length
		args[i] = v for v, i in args1
		args[args1.length + i] = v for v, i in args2
		args
	g = (args2, g) ->
		args = a args2
		fn = do c
		if typeof args2[args2.length - 1] == 'function'
			fn.cb = args2[args2.length - 1]
			args.length--
		fn.g = g args
		do fn
		return
	if args1[0].constructor == GeneratorFunction
		return (() -> g arguments, (args) -> new (Function::bind.apply args[0], args)) if @.constructor == arguments.callee
		return () -> g arguments, if @constructor == arguments.callee then (args) -> new (Function::bind.apply args[0], args) else (args) -> Function::call.apply args[0], args
	if @.constructor == arguments.callee
		return () ->
			args = a arguments
			new (Function::bind.apply args[0], args)
	() ->
		args = a arguments
		Function::call.apply args[0], args
		return

module.exports = $