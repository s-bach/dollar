'''#############################################################v4''
#
#                     The dollar function ($)
#                       by Christoph Bach (C)
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
	a1 = Array::slice.call arguments, 0
	#a1 = arguments
	throw new Error 'The first parameter must be callable.' if typeof a1[0] != 'function'
	throw new Error 'The first parameter must be a Function or a GeneratorFunction.' unless a1[0].constructor in [Function, GeneratorFunction]
	g = (a2) ->
		a = Array a1.length + a2.length
		a[i] = v for v, i in a1
		a[a1.length + i] = v for v, i in a2
		a
	if a1[0].constructor == GeneratorFunction
		assert @.constructor != arguments.callee
		return () ->
			a = g arguments
			f = do c
			if typeof arguments[arguments.length - 1] == 'function'
				f.cb = arguments[arguments.length - 1]
				a.length--
			f.g = a[0].call this, a.slice(1)...
			do f
			return
	if @.constructor == arguments.callee
		return () ->
			a = g arguments
			new (Function::bind.apply a[0], a)
	() ->
		a = g arguments
		Function::call.apply a[0], a
		return

module.exports = $