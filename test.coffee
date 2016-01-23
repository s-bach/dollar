$ = require './dollar'
EventEmitter = require 'events'
{$Promise} = require './dollar-promise'
assert = require 'assert'

String::toTitleCase = ->
	i = undefined
	j = undefined
	str = undefined
	lowers = undefined
	uppers = undefined
	str = @replace(/([^\W_]+[^\s-]*) */g, (txt) ->
		if txt.toLowerCase() == txt
			txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()
		else
			txt
	)
	# Certain minor words should be left lowercase unless 
	# they are the first or last words in the string
	lowers = 'A,An,The,And,But,Or,For,Nor,As,At,By,For,From,In,Into,Near,Of,On,Onto,To,With,That,Are,About'.split ','
	i = 0
	j = lowers.length
	while i < j
		str = str.replace(new RegExp('\\s' + lowers[i] + '\\s', 'g'), (txt) ->
			txt.toLowerCase()
		)
		i++
	# Certain words such as initialisms or acronyms should be left uppercase
	uppers = 'Id,Tv'.split ','
	i = 0
	j = uppers.length
	while i < j
		str = str.replace(new RegExp('\\b' + uppers[i] + '\\b', 'g'), uppers[i].toUpperCase())
		i++
	str.replace /\\[^ \\]+/g, (txt) -> txt.toLowerCase()

class Test extends EventEmitter
	count = 0
	constructor: (@name, @task) ->
		@errors = []
		@log = []
		@state = 'pending'
		@name = @name.toTitleCase() + ' (' + (++count) + ')'
	run: () ->
		if @state != 'pending'
			@addError new Error 'Warning: State was ' + @state + ' and not pending.'
		else
			@state = 'running'
			fulfill = @fulfill.bind @
			reject = @reject.bind @
			console = log: () => @log.push [arguments...]
			process.nextTick () =>
				@task fulfill, reject, console
	fulfill: () ->
		if @state != 'running'
			@errors.push new Error 'Warning: State was ' + @state + ' and not running.'
		else
			@done false
	reject: () ->
		if @state != 'running'
			@errors.push new Error 'Warning: State was ' + @state + ' and not running.'
		else
			@errors.push new Error 'reject'
			@done true
	done: (err) ->
		if err
			@state = ' ERROR '
		else
			@state = '   ✓   '
		@emit 'done', err
	inspect: () ->
		'   ' + Array(20 - Math.floor @name.length / 2).join(' ') + @name + Array(20 - Math.ceil @name.length / 2).join(' ') + ' | ' + @state + '   '

class TestRunner
	constructor: () ->
		@tests = []
		
		# test 1
		# bind
		@tests.push new Test 'bind', (fulfill, reject, console) ->
			ok = false
			f = (a, b, c, d) ->
				assert a == 'a'
				assert b == 'b'
				assert c == 'c'
				assert d == undefined
				ok = true
			g = $ f
			g 'a', 'b', 'c'
			assert ok
			ok = false
			g = $ f, 'a'
			g 'b', 'c'
			assert ok
			ok = false
			g = $ f, 'a', 'b'
			g 'c'
			assert ok
			ok = false
			g = $ f, 'a', 'b', 'c'
			do g
			assert ok
			do fulfill

		# test 2
		# one parm callback
		@tests.push new Test 'one parm callback', (fulfill, reject, console) ->
			count = 3
			f1 = (cb) ->
				do cb
			f2 = (cb) ->
				cb null, 'a'
			do $ () ->
				re = yield $ f1
				assert re == undefined
				count--
				do reject if count < 0
				do fulfill if count == 0
			do $ () ->
				re = yield $ f2
				assert re == 'a'
				count--
				do reject if count < 0
				do fulfill if count == 0
			do $ () ->
				re = yield $ f1
				assert re == undefined
				re = yield $ f2
				assert re == 'a'
				count--
				do reject if count < 0
				do fulfill if count == 0


		# test 3
		# two levels
		@tests.push new Test 'two levels', (fulfill, reject, console) ->
			f = $ () ->
				re = yield $ () ->
					yield $ (cb) -> do cb
					yield $ (cb) -> do cb
					15
				assert re == 15
				re
			f (err, val) ->
				assert val == 15
				do fulfill

		# test 4
		# speed
		@tests.push new Test 'speed', (fulfill, reject, console) ->
			f = $ (cb) -> process.nextTick cb
			ok = false
			g = $ () ->
				start = new Date
				i = 0
				while i++ < 1000000
					$ (cb) -> process.nextTick cb
				speed1 = i / (new Date() - start)
				assert speed1 > 1300 # more than 1.3m iter per second are ok
				start = new Date
				i = 0
				while i++ < 1000000
					yield f
				speed2 = i / (new Date() - start)
				assert speed2 > 1000 # more than 1m iter per second are ok
				start = new Date
				i = 0
				while i++ < 1000000
					yield $ (cb) -> process.nextTick cb
				speed3 = i / (new Date() - start)
				assert speed3 > 500 # more than 700k iter per second are cool
				ok = true
				console.log speed1
				console.log speed2
				console.log speed3
			g (err) ->
				throw err if err?
				assert ok
				do fulfill

		# test 5
		# new
		@tests.push new Test 'new', (fulfill, reject, console) ->
			class A
				constructor: (a, b, c) ->
					assert a + b + c == 'abc'
					assert @__proto__ == A::
					assert @ instanceof A
					yield $ (cb) -> do cb
					return @ # Seems to be a bug that this return is needed...
			class B
				constructor: (a, b, c, cb) ->
					assert a + b + c == 'abc'
					assert @__proto__ == B::
					assert @ instanceof B
					cb null, @
			ok = false
			do $ () ->
				try
					a = yield new $ A, 'a', 'b', 'c'
					assert a instanceof A
					assert a.constructor == A::constructor

					a = yield new $ A, 'a', 'b', 'c'
					assert a instanceof A
					assert a.constructor == A::constructor

					b = yield new $ B, 'a', 'b', 'c'
					assert b instanceof B
					assert b.constructor == B::constructor

					b = yield new $ B, 'a', 'b', 'c'
					assert b instanceof B
					assert b.constructor == B::constructor
				catch e
					console.log e.stack
				ok = true
			assert ok
			do fulfill

		# test 6
		# errors! try-_throw-_catch->  !
		@tests.push new Test 'errors! try-_throw-_catch->  !', (fulfill, reject, console) ->
			count = 3
			do $ () ->
				ok = false
				throwen = false
				stops = true
				yield $ () ->
					try
						yield $ (cb) -> cb 'e'
						stops = false
					catch e
						assert e == 'e'
						throwen = true
					ok = true
				assert throwen
				assert ok
				assert stops
				count--
				do reject if count < 0
				do fulfill if count == 0
			do $ () ->
				ok = false
				throwen = false
				stops = true
				yield $ () ->
					try
						yield $ (cb) -> throw 'e'
						stops = false
					catch e
						assert e == 'e'
						throwen = true
					ok = true
				assert throwen
				assert ok
				assert stops
				count--
				do reject if count < 0
				do fulfill if count == 0
			catches = 0
			class A
				constructor: $ () ->
					try
						yield throw 'e'
					catch e
						catches++
						assert e == 'e'
						throw e
			f = $ () ->
				try
					yield new $ A
				catch e
					catches++
					assert e == 'e'
					throw e
			try
				f (e, v) ->
					catches++
					assert e == 'e'
					throw e
			catch e
				catches++
				assert e == 'e'
				assert catches == 4
				count--
				do reject if count < 0
				do fulfill if count == 0

		# test 7
		# reuse
		@tests.push new Test 'reuse', (fulfill, reject, console) ->
			i = 0
			f = $ (cb) ->
				i++
				cb null, i

			f (err, val) ->
				assert !err?
				assert i == 1
			assert i == 1

			f (err, val) ->
				assert i == 2
			assert i == 2

			f = $ (cb) ->
				i++
				yield $ (cb) -> do cb

			f (err, val) ->
				assert i == 3
			assert i == 3

			f (err, val) ->
				assert i == 4
			assert i == 4
			do fulfill

		# test 8
		# use as promise
		@tests.push new Test 'use as promise', (fulfill, reject, console) ->
			ok = false
			error = false
			works = 0
			$Promise (cb) ->
				cb null, 'ok'
				return
			.then () ->
				ok = true
				return
			, () ->
				error = true
				return
			.then () ->
				assert ok
				assert !error
				works++
				return
			$Promise (cb) ->
				cb 1
			.catch () ->
				works++
				return
			$Promise () ->
				yield $ (cb) ->
					setTimeout cb, 5
				return
			.then () ->
				works++
				return
			setTimeout () ->
				assert works == 3
				do fulfill
			,
				10

		# test 9
		# shortcuts 1
		@tests.push new Test 'shortcuts 1', (fulfill, reject, console) ->
			ok = false
			do $ () ->
				yield (cb) -> do cb
				ok = true
			assert ok
			do $ () ->
				yield $ (cb) ->
					setTimeout cb, 2
				assert ok
				do fulfill

		# test 10
		# shortcuts 2
		@tests.push new Test 'shortcuts 2', (fulfill, reject, console) ->
			ok = false
			do $ () ->
				yield () ->
					yield (cb) -> do cb
					ok = true
			assert ok
			do fulfill

		# test 12
		# a even better constructor test
		@tests.push new Test 'a even better constructor test', (fulfill, reject, console) ->
			class X
				constructor: $ (cb) ->
					setTimeout cb, 10

			do $ () ->
				x = yield new $ X
				return do fulfill if x instanceof X
				do reject 

		# test 13
		# yield a Promise
		@tests.push new Test 'yield a Promise 1', (fulfill, reject, console) ->
			ok = false
			do $ () ->
				x =
					then: (fulfill, reject) ->
						try
							do reject
						catch
							assert false
				try
					yield x
				catch e
					ok = true
			assert ok
			do fulfill

		# test 14
		# yield a Promise 2
		@tests.push new Test 'yield a Promise 2', (fulfill, reject, console) ->
			ok = false
			do $ () ->
				x =
					new Promise (fulfill, reject) ->
						try
							do reject
						catch
							assert false
				try
					yield x
				catch e
					ok = true
			setTimeout () -> # wait for Promise to execute
				assert ok
				do fulfill
			, 100

		# test 16
		# yield a Promise 3
		@tests.push new Test 'yield a Promise 3', (fulfill, reject, console) ->
			ok = false
			do $ () ->
				x =
					new Promise (fulfill, reject) ->
						try
							do fulfill
						catch
							assert false
				try
					yield x
				catch e
					assert false
				ok = true
			setTimeout () -> # wait for Promise to execute
				assert ok
				do fulfill
			, 100

		# test 17
		# yield a Promise 4
		@tests.push new Test 'yield a Promise 4', (fulfill, reject, console) ->
			ok = false
			do $ () ->
				x =
					then: (fulfill, reject) ->
						try
							throw 42
						catch e
							assert e == 42
							ok = true
				try
					yield x
				catch e
					do reject
			assert ok
			do fulfill

		# test 18
		# yield a Promise 5
		@tests.push new Test 'yield a Promise 5', (fulfill, reject, console) ->
			ok = false
			do $ () ->
				x =
					new Promise (fulfill, reject) ->
						try
							throw 'a'
						catch e
							assert e == 'a'
							ok = true
				try
					yield x
				catch e
					do reject
			setTimeout () -> # wait for Promise to execute
				assert ok
				do fulfill
			, 100

		# test 19
		# yield a Promise 2
		@tests.push new Test 'yield a Promise 6', (fulfill, reject, console) ->
			ok = false
			process.once 'uncaughtException', () ->
				ok = true
			do $ () ->
				yield new Promise () -> throw 'a'
			setTimeout () -> # wait for Promise to execute
				assert ok
				do fulfill
			, 100

		# test 20
		# two Promises
		@tests.push new Test 'two Promises', (fulfill, reject, console) ->
			ok = false
			do $ () ->
				console.log 'run the first Promise'
				yield then: (fulfill) ->
					console.log 'fulfill the first Promise'
					do fulfill
				console.log 'run the second Promise'
				yield then: (fulfill) ->
					console.log 'fulfill the second Promise'
					do fulfill
				yield new Promise (fulfill) -> do fulfill
				ok = true
			setTimeout () ->
				do fulfill if ok
			, 100

		# test 21
		# throw undefined value
		@tests.push new Test 'throw undefined value', (fulfill, reject, console) ->
			($ () -> yield () -> throw undefined) (err, val) -> do if err == undefined then fulfill else reject

		# test 22
		# promise try catch throw
		@tests.push new Test 'promise try catch throw', (fulfill, reject, console) ->
			r = do $ () ->
				try
					console.log 'yield the first promise'
					yield new Promise (fulfill, reject) -> do reject
				catch err
					console.log 'catching reject'
				console.log 'yield the second promise'
				yield new Promise (fulfill, reject) -> do fulfill
				assert r == undefined
				do fulfill

		# test 22
		# promise try catch throw
		@tests.push new Test 'other promise try catch throw', (fulfill, reject, console) ->
			f = $ () ->
				yield new Promise (fulfill, reject) -> reject 'jo!'
			f (err, val) ->
				assert err == 'jo!'
				do fulfill

		# test 23
		# promise try catch throw
		@tests.push new Test 'other promise try catch throw', (fulfill, reject, console) ->
			f = $ () ->
				try
					yield new Promise (fulfill, reject) -> reject 'jo!'
				catch e
					throw 'jo'
			f (err, val) ->
				assert err == 'jo'
				do fulfill

		# test 24
		# a better constructor test
		@tests.push new Test 'a better constructor test', (fulfill, reject, console) ->
			class X
				constructor: $ () ->
					yield (cb) ->
						setTimeout cb, 10
					return @
				x: () ->
			count = 2
			# ok now we start instantiation tests
			val = null
			q = (new $ X) (err, v) ->
				val = v
				assert val instanceof X
				assert val.constructor == X
				assert val.x == X::x
				assert !q? || q == val
				count--
				do fulfill if count == 0
			assert q instanceof X
			assert q.constructor == X
			assert q.x == X::x
			assert !val? || q == val
			count--
			do fulfill if count == 0

		@state = 'pending'
	runSync: () ->
		if @state != 'pending'
			return
		@state = 'running'
		count = @tests.length
		console.log @
		pos = 0
		onBeforeExit = () =>
			@tests[pos].errors.push new Error 'Test "' + @tests[pos].name + '" does not terminate.'
			do @tests[pos].reject
		process.on 'beforeExit', onBeforeExit
		original_log = console.log
		for test in @tests
			test.once 'done', () =>
				console.log = original_log
				console.log @
				count--
				if count == 0
					process.removeListener 'beforeExit', onBeforeExit
					for {errors, state, log} in @tests when state.trim() == 'ERROR'
						console.log line... for line in log
						for error in errors
							console.log error.stack
				else
					pos++
					#console.log = () => @tests[pos].log.push [arguments...]
					@tests[pos].run()
		#console.log = () => @tests[pos].log.push [arguments...]
		@tests[pos].run()
	inspect: () ->
		re = [' +----------------------------------------+---------+ ']
		re.push (do test.inspect for test in @tests).join '\n'# '\n  -------------------------------------------------- \n'
		re.push ' +----------------------------------------+---------+ '
		re.join '\n'

new TestRunner().runSync()