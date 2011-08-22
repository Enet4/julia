## abstractarray.j : Generic array interfaces.

## Type aliases for convenience ##

typealias AbstractVector{T} AbstractArray{T,1}
typealias AbstractMatrix{T} AbstractArray{T,2}

typealias Indices{T<:Int} Union(Int, AbstractVector{T})
typealias Region Union(Size,Dims)

typealias RangeIndex Union(Index, Range{Index}, Range1{Index})

## Basic functions ##

size(t::AbstractArray, d) = size(t)[d]
eltype{T,n}(::AbstractArray{T,n}) = T
ndims{T,n}(::AbstractArray{T,n}) = n
numel(t::AbstractArray) = prod(size(t))
length(a::AbstractArray) = numel(a)
nnz(a::AbstractArray) = (n = 0; for i=1:numel(a); n += a[i] != 0 ? 1 : 0; end; n)
nnz(a::AbstractArray{Bool}) = (n = 0; for i=1:numel(a); n += a[i] == true ? 1 : 0; end; n)

function stride(a::AbstractArray, i::Int)
    s = 1
    for n=1:(i-1)
        s *= size(a, n)
    end
    s
end
strides{T}(a::AbstractArray{T,1}) = (1,)
strides{T}(a::AbstractArray{T,2}) = (1, size(a,1))
strides{T}(a::AbstractArray{T,3}) = (1, size(a,1), size(a,1)*size(a,2))
strides   (a::AbstractArray)      = ntuple(ndims(a), i->stride(a,i))

iscomplex{T<:Complex}(x::AbstractArray{T}) = true

## Constructors ##

# default arguments to similar()
similar{T}(a::AbstractArray{T})                      = similar(a, T, size(a))
similar   (a::AbstractArray, T::Type)                = similar(a, T, size(a))
similar{T}(a::AbstractArray{T}, dims::Dims)          = similar(a, T, dims)
similar{T}(a::AbstractArray{T}, dims::Size...)       = similar(a, T, dims)
similar   (a::AbstractArray, T::Type, dims::Size...) = similar(a, T, dims)

reshape(a::AbstractArray, dims::Dims) = (b = similar(a, dims);
                                  for i=1:numel(a); b[i] = a[i]; end;
                                  b)
reshape(a::AbstractArray, dims::Size...) = reshape(a, dims)

function fill(A::AbstractArray, x)
    for i = 1:numel(A)
        A[i] = x
    end
    return A
end

function copy_to(dest::AbstractArray, src::AbstractArray)
    for i=1:numel(src)
        dest[i] = copy(src[i])
    end
    return dest
end

copy(a::AbstractArray) = copy_to(similar(a), a)

eye(n::Size) = eye(n, n)
eye(m::Size, n::Size) = (a = zeros(m,n);
                         for i=1:min(m,n); a[i,i]=1; end;
                         a)
one{T}(x::AbstractArray{T,2}) = (m=size(x,1); n=size(x,2);
                          a = zeros(T,size(x));
                          for i=1:min(m,n); a[i,i]=1; end;
                          a)
zero{T}(x::AbstractArray{T,2}) = zeros(T,size(x))

function linspace(start::Real, stop::Real, n::Int)
    (start, stop) = promote(start, stop)
    a = Array(typeof(start), long(n))
    step = (stop-start)/(n-1)
    for i=1:n
        a[i] = start+(i-1)*step
    end
    a
end

linspace(start::Real, stop::Real) = [ i | i=start:stop ]

## Unary operators ##

conj{T <: Real}(x::AbstractArray{T}) = x
real{T <: Real}(x::AbstractArray{T}) = x
imag{T <: Real}(x::AbstractArray{T}) = zero(x)

macro unary_op(f)
    quote

        function ($f)(A::AbstractArray)
            F = similar(A)
            for i=1:numel(A)
                F[i] = ($f)(A[i])
            end
            return F
        end

    end # quote
end # macro

@unary_op (-)
@unary_op (~)
@unary_op (conj)

macro unary_c2r_op(f)
    quote

        function ($f){T}(A::AbstractArray{T})
            S = typeof(($f)(zero(T)))
            F = similar(A, S)
            for i=1:numel(A)
                F[i] = ($f)(A[i])
            end
            return F
        end

    end # quote
end # macro

@unary_c2r_op (real)
@unary_c2r_op (imag)

+{T<:Number}(x::AbstractArray{T}) = x
*{T<:Number}(x::AbstractArray{T}) = x

function !(A::AbstractArray{Bool})
    F = similar(A)
    for i=1:numel(A)
        F[i] = !A[i]
    end
    return F
end

## Binary arithmetic operators ##

*(A::Number, B::AbstractArray) = A .* B
*(A::AbstractArray, B::Number) = A .* B

./(x::AbstractArray, y::AbstractArray) = reshape( [ x[i] ./ y[i] | i=1:numel(x) ], size(x) )
./(x::Number,        y::AbstractArray) = reshape( [ x    ./ y[i] | i=1:numel(y) ], size(y) )
./(x::AbstractArray, y::Number       ) = reshape( [ x[i] ./ y    | i=1:numel(x) ], size(x) )

/(A::Number, B::AbstractArray) = A ./ B
/(A::AbstractArray, B::Number) = A ./ B

\(A::Number, B::AbstractArray) = B ./ A
\(A::AbstractArray, B::Number) = B ./ A

# ^ is difficult, since negative exponents give a different type

.^(x::AbstractArray, y::AbstractArray) = reshape( [ x[i] ^ y[i] | i=1:numel(x) ], size(x) )
.^(x::Number,        y::AbstractArray) = reshape( [ x    ^ y[i] | i=1:numel(y) ], size(y) )
.^(x::AbstractArray, y::Number       ) = reshape( [ x[i] ^ y    | i=1:numel(x) ], size(x) )

function .^{S<:Int,T<:Int}(A::AbstractArray{S}, B::AbstractArray{T})
    if size(A) != size(B); error("Inputs should be of same shape and size"); end
    F = similar(A, Float64)
    for i=1:numel(A)
        F[i] = A[i]^B[i]
    end
    return F
end

function .^{T<:Int}(A::Int, B::AbstractArray{T})
    F = similar(B, Float64)
    for i=1:numel(B)
        F[i] = A^B[i]
    end
    return F
end

function power_array_int_body(F, A, B)
    for i=1:numel(A)
        F[i] = A[i]^B
    end
    return F
end

function .^{T<:Int}(A::AbstractArray{T}, B::Int)
    F = similar(A, B < 0 ? Float64 : promote_type(T,typeof(B)))
    power_array_int_body(F, A, B)
end

macro binary_arithmetic_op(f)
    quote

        function ($f){S,T}(A::AbstractArray{S}, B::AbstractArray{T})
            if size(A) != size(B); error("Inputs should be of same shape and size"); end
            F = similar(A, promote_type(S,T))
            for i=1:numel(A)
                F[i] = ($f)(A[i], B[i])
            end
            return F
        end
        function ($f){T}(A::Number, B::AbstractArray{T})
            F = similar(B, promote_type(typeof(A),T))
            for i=1:numel(B)
                F[i] = ($f)(A, B[i])
            end
            return F
        end
        function ($f){T}(A::AbstractArray{T}, B::Number)
            F = similar(A, promote_type(T,typeof(B)))
            for i=1:numel(A)
                F[i] = ($f)(A[i], B)
            end
            return F
        end

    end # quote
end # macro

@binary_arithmetic_op (+)
@binary_arithmetic_op (-)
@binary_arithmetic_op (.*)
@binary_arithmetic_op div
@binary_arithmetic_op mod

## promotion to complex ##

function complex{S<:Real,T<:Real}(A::AbstractArray{S}, B::AbstractArray{T})
    F = similar(A, typeof(complex(zero(S),zero(T))))
    for i=1:numel(A)
        F[i] = complex(A[i], B[i])
    end
    return F
end

function complex{T<:Real}(A::Real, B::AbstractArray{T})
    F = similar(B, typeof(complex(A,zero(T))))
    for i=1:numel(B)
        F[i] = complex(A, B[i])
    end
    return F
end

function complex{T<:Real}(A::AbstractArray{T}, B::Real)
    F = similar(A, typeof(complex(zero(T),B)))
    for i=1:numel(A)
        F[i] = complex(A[i], B)
    end
    return F
end

function complex{T<:Real}(A::AbstractArray{T})
    z = zero(T)
    F = similar(A, typeof(complex(z,z)))
    for i=1:numel(A)
        F[i] = complex(A[i], z)
    end
    return F
end

## Binary comparison operators ##

macro binary_comparison_op(f)
    quote

        function ($f)(A::AbstractArray, B::AbstractArray)
            if size(A) != size(B); error("Inputs should be of same shape and size"); end
            F = similar(A, Bool)
            for i=1:numel(A)
                F[i] = ($f)(A[i], B[i])
            end
            return F
        end
        function ($f)(A::Number, B::AbstractArray)
            F = similar(B, Bool)
            for i=1:numel(B)
                F[i] = ($f)(A, B[i])
            end
            return F
        end
        function ($f)(A::AbstractArray, B::Number)
            F = similar(A, Bool)
            for i=1:numel(A)
                F[i] = ($f)(A[i], B)
            end
            return F
        end
    end
end

@binary_comparison_op (==)
@binary_comparison_op (!=)
@binary_comparison_op (<)
@binary_comparison_op (>)
@binary_comparison_op (<=)
@binary_comparison_op (>=)

## Binary boolean operators ##

macro binary_boolean_op(f)
    quote

        function ($f)(A::AbstractArray{Bool}, B::AbstractArray{Bool})
            if size(A) != size(B); error("Inputs should be of same shape and size"); end
            F = similar(A, Bool)
            for i=1:numel(A)
                F[i] = ($f)(A[i], B[i])
            end
            return F
        end
        function ($f)(A::Bool, B::AbstractArray{Bool})
            F = similar(B, Bool)
            for i=1:numel(B)
                F[i] = ($f)(A, B[i])
            end
            return F
        end
        function ($f)(A::AbstractArray{Bool}, B::Bool)
            F = similar(A, Bool)
            for i=1:numel(A)
                F[i] = ($f)(A[i], B)
            end
            return F
        end

    end # quote
end # macro

@binary_boolean_op (&)
@binary_boolean_op (|)
@binary_boolean_op ($)

## code generator for specializing on the number of dimensions ##

#otherbodies are the bodies that reside between loops, if its a 2 dimension array. 
function make_loop_nest(vars, ranges, body)
    otherbodies = cell(length(vars),2)
    #println(vars)
    for i = 1:2*length(vars)
        otherbodies[i]= nothing
    end
    make_loop_nest(vars, ranges, body, otherbodies)
end


function make_loop_nest(vars, ranges, body, otherbodies)
    expr = body
    len = size(otherbodies)[1]
    for i=1:length(vars)
        v = vars[i]
        r = ranges[i]
        l = otherbodies[i]
        j = otherbodies[i+len]
        expr = quote
            $l
            for ($v) = ($r)
                $expr
            end
            $j
        end
    end
    expr
end

## genbodies() is a function that creates an array (potentially 2d), 
## where the first element is inside the inner most array, and the last 
## element is outside most loop, and all the other arguments are 
## between each loop. If it creates a 2d array, it just means that it 
## specifies what it wants to do before and after each loop.
## If genbodies creates an array it must of length N.
function gen_cartesian_map(cache, genbodies, ranges, exargnames, exargs...)
    N = length(ranges)
    if !has(cache,N)
        dimargnames = { gensym() | i=1:N }
        ivars = { gensym() | i=1:N }
        bodies = genbodies(ivars)

        ## creating a 2d array, to pass as bodies
        if isa(bodies,Array)
            if (ndims(bodies)==2)
                #println("2d array noticed")
	        body = bodies[1]
	        bodies = bodies[2:end,:]
            elseif (ndims(bodies)==1)
                #println("1d array noticed")
                body = bodies[1]
                bodies_tmp = cell(N,2)
                for i = 1:N
                    bodies_tmp[i] = bodies[i+1]
                    bodies_tmp[i+N] = nothing
                end
                bodies = bodies_tmp
            end
        else
            #println("no array noticed")
	    body = bodies
            bodies = cell(N,2)
            { bodies[i] = nothing | i = 1:2*N}
        end
        fexpr =
        quote
            local _F_
            function _F_($(dimargnames...), $(exargnames...))
                $make_loop_nest(ivars, dimargnames, body, bodies)
            end
            _F_
        end
        f = eval(fexpr)
        cache[N] = f
    else
        f = cache[N]
    end
    return f(ranges..., exargs...)
end

## Indexing: ref ##

ref(t::AbstractArray) = t
ref(t::AbstractArray, i::Int) = error("indexing not defined for ", typeof(t))
ref(t::AbstractArray, i::Real)          = ref(t, iround(i))
ref(t::AbstractArray, i::Real, j::Real) = ref(t, iround(i), iround(j))
ref(t::AbstractArray, i::Real, j::Real, k::Real) =
    ref(t, iround(i), iround(j), iround(k))
ref(t::AbstractArray, r::Real...)       = ref(t,map(iround,r)...)

ref{T<:Int}(A::AbstractVector, I::AbstractVector{T}) = [ A[i] | i = I ]
ref{T<:Int}(A::AbstractArray{Any,1}, I::AbstractVector{T}) = { A[i] | i = I }

ref{T<:Int}(A::AbstractMatrix, I::Int, J::AbstractVector{T})       = [ A[i,j] | i = I, j = J ]
ref{T<:Int}(A::AbstractMatrix, I::AbstractVector{T}, J::Int)       = [ A[i,j] | i = I, j = J ]
ref{T<:Int}(A::AbstractMatrix, I::AbstractVector{T}, J::AbstractVector{T}) = [ A[i,j] | i = I, j = J ]

function ref(A::AbstractArray, i0::Int, i1::Int)
    A[i0 + size(A,1)*(i1-1)]
end

function ref(A::AbstractArray, i0::Int, i1::Int, i2::Int)
    A[i0 + size(A,1)*((i1-1) + size(A,2)*(i2-1))]
end

function ref(A::AbstractArray, i0::Int, i1::Int, i2::Int, i3::Int)
    A[i0 + size(A,1)*((i1-1) + size(A,2)*((i2-1) + size(A,3)*(i3-1)))]
end

function ref(A::AbstractArray, I::Int...)
    dims = size(A)
    ndims = length(I)

    index = I[1]
    stride = 1
    for k=2:ndims
        stride = stride * dims[k-1]
        index += (I[k]-1) * stride
    end

    return A[index]
end

let ref_cache = nothing
global ref
function ref(A::AbstractArray, I::Indices...)
    X = similar(A, map(length, I))

    if is(ref_cache,nothing)
        ref_cache = HashTable()
    end
    gen_cartesian_map(ref_cache, ivars->:(X[storeind] = A[$(ivars...)];
                                          storeind += 1),
                      I,
                      {:A, :X, :storeind},
                      A, X, 1)
    return X
end
end

## Indexing: assign ##

# 1-d indexing is assumed defined on subtypes
assign(t::AbstractArray, x, i::Int) =
    error("assign not defined for ",typeof(t))
assign(t::AbstractArray, x::AbstractArray, i::Int) =
    error("assign not defined for ",typeof(t))

assign(t::AbstractArray, x, i::Real)          = (t[iround(i)] = x)
assign(t::AbstractArray, x, i::Real, j::Real) = (t[iround(i),iround(j)] = x)
assign(t::AbstractArray, x, i::Real, j::Real, k::Real) =
    (t[iround(i),iround(j),iround(k)] = x)
assign(t::AbstractArray, x, r::Real...)       = (t[map(iround,r)...] = x)

function assign{T<:Int}(A::AbstractVector, x, I::AbstractVector{T})
    for i=I
        A[i] = x
    end
    return A
end

function assign{T<:Int}(A::AbstractVector, X::AbstractArray, I::AbstractVector{T})
    for i=1:length(I)
        A[I[i]] = X[i]
    end
    return A
end

assign(A::AbstractMatrix, x, i::Int, j::Int) = (A[(j-1)*size(A,1) + i] = x)
assign(A::AbstractMatrix, x::AbstractArray, i::Int, j::Int) = (A[(j-1)*size(A,1) + i] = x)

function assign(A::AbstractMatrix, x, I::Indices, J::Indices)
    for j=J, i=I
        A[i,j] = x
    end
    return A
end

function assign(A::AbstractMatrix, X::AbstractArray, I::Indices, J::Indices)
    count = 1
    for j=J, i=I
        A[i,j] = X[count]
        count += 1
    end
    return A
end

assign(A::AbstractArray, x, I0::Int, I::Int...) = assign_scalarND(A,x,I0,I...)
assign(A::AbstractArray, x::AbstractArray, I0::Int, I::Int...) =
    assign_scalarND(A,x,I0,I...)

assign(A::AbstractArray, x::AbstractArray, i0::Int, i1::Int) = A[i0 + size(A,1)*(i1-1)] = x
assign(A::AbstractArray, x, i0::Int, i1::Int) = A[i0 + size(A,1)*(i1-1)] = x

assign(A::AbstractArray, x, i0::Int, i1::Int, i2::Int) =
    A[i0 + size(A,1)*((i1-1) + size(A,2)*(i2-1))] = x
assign(A::AbstractArray, x::AbstractArray, i0::Int, i1::Int, i2::Int) =
    A[i0 + size(A,1)*((i1-1) + size(A,2)*(i2-1))] = x

assign(A::AbstractArray, x, i0::Int, i1::Int, i2::Int, i3::Int) =
    A[i0 + size(A,1)*((i1-1) + size(A,2)*((i2-1) + size(A,3)*(i3-1)))] = x
assign(A::AbstractArray, x::AbstractArray, i0::Int, i1::Int, i2::Int, i3::Int) =
    A[i0 + size(A,1)*((i1-1) + size(A,2)*((i2-1) + size(A,3)*(i3-1)))] = x

function assign_scalarND(A, x, I0, I...)
    dims = size(A)
    index = I0
    stride = 1
    for k=1:length(I)
        stride = stride * dims[k]
        index += (I[k]-1) * stride
    end
    A[index] = x
    return A
end

let assign_cache = nothing
global assign
function assign(A::AbstractArray, x, I0::Indices, I::Indices...)
    if is(assign_cache,nothing)
        assign_cache = HashTable()
    end
    gen_cartesian_map(assign_cache, ivars->:(A[$(ivars...)] = x),
                      append(tuple(I0), I),
                      {:A, :x},
                      A, x)
    return A
end
end

let assign_cache = nothing
global assign
function assign(A::AbstractArray, X::AbstractArray, I0::Indices, I::Indices...)
    if is(assign_cache,nothing)
        assign_cache = HashTable()
    end
    gen_cartesian_map(assign_cache, ivars->:(A[$(ivars...)] = X[refind];
                                             refind += 1),
                      append(tuple(I0), I),
                      {:A, :X, :refind},
                      A, X, 1)
    return A
end
end

## Reductions ##

function contains(itr, x)
    for y=itr
        if y==x
            return true
        end
    end
    return false
end

contains(s::Number, n::Int) = (s == n)

areduce{T}(f::Function, A::AbstractArray{T}, region::Region, v0) =
        areduce(f,A,region,v0,T)

# TODO:
# - find out why inner loop with dimsA[i] instead of size(A,i) is way too slow

let areduce_cache = nothing
# generate the body of the N-d loop to compute a reduction
function gen_areduce_func(n, f)
    ivars = { gensym() | i=1:n }
    # limits and vars for reduction loop
    lo    = { gensym() | i=1:n }
    hi    = { gensym() | i=1:n }
    rvars = { gensym() | i=1:n }
    setlims = { quote
        # each dim of reduction is either 1:sizeA or ivar:ivar
        if contains(region,$i)
            $lo[i] = 1
            $hi[i] = size(A,$i)
        else
            $lo[i] = $hi[i] = $ivars[i]
        end
               end | i=1:n }
    rranges = { :( ($lo[i]):($hi[i]) ) | i=1:n }  # lo:hi for all dims
    body =
    quote
        _tot = v0
        $(setlims...)
        $make_loop_nest(rvars, rranges,
                        :(_tot = ($f)(_tot, A[$(rvars...)])))
        R[_ind] = _tot
        _ind += 1
    end
    quote
        local _F_
        function _F_(f, A, region, R, v0)
            _ind = 1
            $make_loop_nest(ivars, { :(1:size(R,$i)) | i=1:n }, body)
        end
        _F_
    end
end

global areduce
function areduce(f::Function, A::AbstractArray, region::Region, v0, RType::Type)
    dimsA = size(A)
    ndimsA = ndims(A)
    dimsR = ntuple(ndimsA, i->(contains(region, i) ? 1 : dimsA[i]))
    R = similar(A, RType, dimsR)
    
    if is(areduce_cache,nothing)
        areduce_cache = HashTable()
    end

    key = ndimsA
    fname = :f

    if  (is(f,+)     && (fname=:+;true)) ||
        (is(f,*)     && (fname=:*;true)) ||
        (is(f,max)   && (fname=:max;true)) ||
        (is(f,min)   && (fname=:min;true)) ||
        (is(f,sum)   && (fname=:+;true)) ||
        (is(f,prod)  && (fname=:*;true)) ||
        (is(f,any)   && (fname=:any;true)) ||
        (is(f,all)   && (fname=:all;true)) ||
        (is(f,count) && (fname=:count;true))
        key = (fname, ndimsA)
    end

    if !has(areduce_cache,key)
        fexpr = gen_areduce_func(ndimsA, fname)
        func = eval(fexpr)
        areduce_cache[key] = func
    else
        func = areduce_cache[key]
    end

    func(f, A, region, R, v0)

    return R
end
end

let areduce_cache = nothing
# generate the body of the N-d loop to compute a reduction
function gen_areduce_func(n, f)
    ivars = { gensym() | i=1:n }
    # limits and vars for reduction loop
    rv = gensym()
    idx = gensym()
    # generate code to compute sub2ind(size(A), ivars...)
    s2i = :($ivars[n] - 1)
    for d = (n-1):-1:2
        s2i = :(($ivars[d]-1) + size(A,$d)*($s2i))
    end
    s2i = :($ivars[1] + size(A,1)*($s2i))
    body =
    quote
        _tot = v0
        $idx = $s2i
        for $rv = 1:size(A,dim)
            _tot = ($f)(_tot, A[$idx])
            $idx += stride
        end
        R[_ind] = _tot
        _ind += 1
    end
    quote
        local _F_
        function _F_(f, A, dim, R, stride)
            _ind = 1
            $make_loop_nest(ivars, { :(1:size(R,$i)) | i=1:n }, body)
        end
        _F_
    end
end

global areduce
function areduce(f::Function, A::AbstractArray, dim::Size, RType::Type)
    dimsA = size(A)
    ndimsA = length(dimsA)
    dimsR = ntuple(ndimsA, i->i==dim ? 1 : dimsA[i])
    R = similar(A, RType, dimsR)
    stride = prod(dimsA[1:(dim-1)])
    
    key = ndimsA
    fname = :f

    if  (is(f,+)     && (fname=:+;true)) ||
        (is(f,*)     && (fname=:*;true)) ||
        (is(f,max)   && (fname=:max;true)) ||
        (is(f,min)   && (fname=:min;true)) ||
        (is(f,sum)   && (fname=:+;true)) ||
        (is(f,prod)  && (fname=:*;true)) ||
        (is(f,any)   && (fname=:any;true)) ||
        (is(f,all)   && (fname=:all;true)) ||
        (is(f,count) && (fname=:count;true))
        key = (fname, ndimsA)
    end

    if !has(areduce_cache,key)
        fexpr = gen_areduce_func(ndimsA, fname)
        func = eval(fexpr)
        areduce_cache[key] = func
    else
        func = areduce_cache[key]
    end

    func(f, A, dim, R, stride)

    return R
end
end

function initial_max_val{T}(::Type{T})
    if subtype(T,Int)
        typemin(T)
    else
        convert(T,-Inf)
    end
end

function initial_min_val{T}(::Type{T})
    if subtype(T,Int)
        typemax(T)
    else
        convert(T,Inf)
    end
end

function max{T}(A::AbstractArray{T})
    v = initial_max_val(T)
    for i=1:numel(A)
        v = max(v,A[i])
    end
    v
end

function min{T}(A::AbstractArray{T})
    v = initial_min_val(T)
    for i=1:numel(A)
        v = min(v,A[i])
    end
    v
end

function sum{T}(A::AbstractArray{T})
    v = zero(T)
    for i=1:numel(A)
        v = sum(v,A[i])
    end
    v
end

function prod{T}(A::AbstractArray{T})
    v = one(T)
    for i=1:numel(A)
        v = prod(v,A[i])
    end
    v
end

max{T}(A::AbstractArray{T}, region::Region) = areduce(max,  A, region,
                                                      initial_max_val(T), T)
min{T}(A::AbstractArray{T}, region::Region) = areduce(min,  A, region,
                                                      initial_min_val(T), T)
sum{T}(A::AbstractArray{T}, region::Region) = areduce(+,  A, region, zero(T))
prod{T}(A::AbstractArray{T}, region::Region) = areduce(*, A, region, one(T))

all(A::AbstractArray{Bool}, region::Region) = areduce(all, A, region, true)
any(A::AbstractArray{Bool}, region::Region) = areduce(any, A, region, false)
count(A::AbstractArray{Bool}, region::Region) = areduce(count, A, region, 0, Size)

function isequal(x::AbstractArray, y::AbstractArray)
    if size(x) != size(y)
        return false
    end

    for i=1:numel(x)
        if !isequal(x[i], y[i])
            return false
        end
    end
    return true
end

for (f, op) = ((:cumsum, :+), (:cumprod, :(.*)) )
    @eval function ($f)(v::AbstractVector)
        n = length(v)
        c = similar(v, n)
        if n == 0; return c; end

        c[1] = v[1]
        for i=2:n
           c[i] = ($op)(v[i], c[i-1])
        end
        return c
    end
end

## iteration support for arrays as ranges ##

start(a::AbstractArray) = 1
next(a::AbstractArray,i) = (a[i],i+1)
done(a::AbstractArray,i) = (i > numel(a))
isempty(a::AbstractArray) = (numel(a) == 0)

## map over arrays ##

## 1 argument
function map_to(dest::AbstractArray, f, A::AbstractArray)
    for i=1:numel(A)
        dest[i] = f(A[i])
    end
    return dest
end

function map(f, A::AbstractArray)
    if isempty(A); return A; end
    first = f(A[1])
    dest = similar(A, typeof(first))
    return map_to(dest, f, A)
end

## 2 argument
function map_to(dest::AbstractArray, f, A::AbstractArray, B::AbstractArray)
    for i=1:numel(A)
        dest[i] = f(A[i], B[i])
    end
    return dest
end

function map(f, A::AbstractArray, B::AbstractArray)
    if size(A) != size(B); error("Input size and shape should be same"); end
    if isempty(A); return A; end
    first = f(A[1], B[1])
    dest = similar(A, typeof(first))
    return map_to(dest, f, A, B)
end

function map_to(dest::AbstractArray, f, A::AbstractArray, B::Number)
    for i=1:numel(A)
        dest[i] = f(A[i], B)
    end
    return dest
end

function map(f, A::AbstractArray, B::Number)
    if isempty(A); return A; end
    first = f(A[1], B)
    dest = similar(A, typeof(first))
    return map_to(dest, f, A, B)
end

function map_to(dest::AbstractArray, f, A::Number, B::AbstractArray)
    for i=1:numel(B)
        dest[i] = f(A, B[i])
    end
    return dest
end

function map(f, A::Number, B::AbstractArray)
    if isempty(A); return A; end
    first = f(A, B[1])
    dest = similar(B, typeof(first))
    return map_to(dest, f, A, B)
end

## N argument
function map_to(dest::AbstractArray, f, As::AbstractArray...)
    n = numel(As[1])
    i = 1
    ith = a->a[i]
    for i=1:n
        dest[i] = f(map(ith, As)...)
    end
    return dest
end

function map(f, As::AbstractArray...)
    if isempty(As[1]); return As[1]; end
    first = f(map(a->a[1], As)...)
    dest = similar(As[1], typeof(first))
    return map_to(dest, f, As...)
end

## Obsolete - Mainly here for reference purposes, use gen_cartesian_map
## Still used in show()
function cartesian_map(body, t::Tuple, it...)
    idx = length(t)-length(it)
    if idx == 0
        body(it)
    else
        for i = t[idx]
            cartesian_map(body, t, i, it...)
        end
    end
end

## Transpose, Permute ##

reverse(v::AbstractVector) = [ v[length(v)-i+1] | i=1:length(v) ]

transpose(x::AbstractVector)  = [ x[j]         | i=1, j=1:size(x,1) ]
ctranspose(x::AbstractVector) = [ conj(x[j])   | i=1, j=1:size(x,1) ]

transpose(x::AbstractMatrix)  = [ x[j,i]       | i=1:size(x,2), j=1:size(x,1) ]
ctranspose(x::AbstractMatrix) = [ conj(x[j,i]) | i=1:size(x,2), j=1:size(x,1) ]

let permute_cache = nothing


global permute
function permute(A::AbstractArray, perm)
    dimsA = size(A)
    ndimsA = length(dimsA)
    dimsP = ntuple(ndimsA, i->dimsA[perm[i]])
    P = similar(A, dimsP)
    ranges = ntuple(ndimsA, i->(Range1(1,dimsP[i])))
    stridenames = {gensym() | i = 1:ndimsA}

    #calculates all the strides
    strides = Array(Int32,0)
    for dim = 1:length(perm)
    	stride = 1
    	for dim_size = 1:(dim-1)
            stride = stride*dimsA[dim_size]
    	end
    	push(strides, stride)
    end

    #reorganizes the ordering of the strides
    strides = { (strides[perm[i]]) | i = 1:ndimsA}

    #Creates offset, because indexing starts at 1
    offset = 0
    for i = strides
        offset+=i
    end
    offset = 1-offset

    function permute_one(ivars)
        len = length(ivars)
        counts = { gensym() | i=1:len}
        toReturn = cell(len+1,2)
        for i = 1:numel(toReturn)
            toReturn[i] = nothing
        end
        
        tmp = counts[end]
        toReturn[len+1] = quote
            ind = 1
            $tmp = $stridenames[end]
        end
        
        #inner most loop
        toReturn[1] = quote
            P[ind] = A[+($counts...)+offset]
            ind+=1
            $counts[1]+= $stridenames[1]
        end
        for i = 1:len-1
            tmp = counts[i]
            val = i
            toReturn[(i+1)] = quote
                $tmp = $stridenames[val]
            end
            tmp2 = counts[i+1]
            val = i+1
            toReturn[(i+1)+(len+1)] = quote
                 $tmp2 += $stridenames[val]
            end
        end
        toReturn
    end


    if is(permute_cache,nothing)
	permute_cache = HashTable()
    end

    gen_cartesian_map(permute_cache, permute_one, ranges, {:A, :P, :perm, :offset, stridenames... }, A, P, perm, offset, strides...)

    return P
end
#end let
end

function ipermute(A::AbstractArray,perm)
    iperm = zeros(Int32,length(perm))
    for i = 1:length(perm)
	    iperm[perm[i]] = i
    end
    return permute(A,iperm)
end

## Other array functions ##

# fallback definition of hvcat in terms of hcat and vcat
function hvcat(rows::(Size...), as...)
    nbr = length(rows)  # number of block rows
    rs = cell(nbr)
    a = 1
    for i = 1:nbr
        rs[i] = hcat(as[a:a-1+rows[i]]...)
        a += rows[i]
    end
    vcat(rs...)
end

function repmat(a::AbstractMatrix, m::Size, n::Size)
    o,p = size(a)
    b = similar(a, o*m, p*n)
    for j=1:n
        d = (j-1)*p+1
        R = d:d+p-1
        for i=1:m
            c = (i-1)*o+1
            b[c:c+o-1, R] = a
        end
    end
    b
end

accumarray(I::AbstractVector, J::AbstractVector, V) = accumarray (I, J, V, max(I), max(J))

function accumarray{T<:Number}(I::AbstractVector, J::AbstractVector, V::T, m::Size, n::Size)
    A = similar(V, m, n)
    for k=1:length(I)
        A[I[k], J[k]] += V
    end
    return A
end

function accumarray(I::Indices, J::Indices, V::AbstractVector, m::Size, n::Size)
    A = similar(V, m, n)
    for k=1:length(I)
        A[I[k], J[k]] += V[k]
    end
    return A
end

function find{T}(A::AbstractVector{T})
    nnzA = nnz(A)
    I = zeros(Size, nnzA)
    z = zero(T)
    count = 1
    for i=1:length(A)
        if A[i] != z
            I[count] = i
            count += 1
        end
    end
    return I
end

function find{T}(A::AbstractMatrix{T})
    nnzA = nnz(A)
    I = zeros(Size, nnzA)
    J = zeros(Size, nnzA)
    z = zero(T)
    count = 1
    for i=1:size(A,1), j=1:size(A,2)
        if A[i,j] != z
            I[count] = i
            J[count] = j
            count += 1
        end
    end
    return (I, J)
end

let find_cache = nothing
function find_one(ivars)
    s = { quote I[$i][count] = $ivars[i] end | i = 1:length(ivars)}
    quote
	Aind = A[$(ivars...)]
	if Aind != z
	    $(s...)
	    count +=1
	end
    end
end

global find
function find{T}(A::AbstractArray{T})
    ndimsA = ndims(A)
    nnzA = nnz(A)
    I = ntuple(ndimsA, x->zeros(Size, nnzA))
    ranges = ntuple(ndims(A), d->(1:size(A,d)))

    if is(find_cache,nothing)
        find_cache = HashTable()
    end

    gen_cartesian_map(find_cache, find_one, ranges, {:A, :I, :count, :z}, A,I,1, zero(T))
    return I
end
end

sub2ind(dims) = 1
sub2ind(dims, i::Int) = i
sub2ind(dims, i::Int, j::Int) = (j-1)*dims[1] + i
sub2ind(dims, i0::Int, i1::Int, i2::Int) =
    i0 + dims[1]*((i1-1) + dims[2]*(i2-1))
sub2ind(dims, i0::Int, i1::Int, i2::Int, i3::Int) =
    i0 + dims[1]*((i1-1) + dims[2]*((i2-1) + dims[3]*(i3-1)))

function sub2ind(dims, I::Int...)
    ndims = length(dims)
    index = I[1]
    stride = 1
    for k=2:ndims
        stride = stride * dims[k-1]
        index += (I[k]-1) * stride
    end
    return index
end

sub2ind(dims, I::AbstractVector...) =
    [ sub2ind(dims, map(X->X[i], I)...) | i=1:length(I[1]) ]

ind2sub(dims::(), ind::Int) = throw(BoundsError())
ind2sub(dims::(Int,), ind::Int) = (ind,)
ind2sub(dims::(Int,Int), ind::Int) =
    (rem(ind-1,dims[1])+1, div(ind-1,dims[1])+1)

function ind2sub(dims, ind::Int)
    ndims = length(dims)
    x = cumprod(dims)

    sub = ()
    for i=(ndims-1):-1:1
        rest = rem(ind-1, x[i]) + 1
        sub = tuple(div(ind - rest, x[i]) + 1, sub...)
        ind = rest
    end
    return tuple(ind, sub...)
end

## subarrays ##

type SubArray{T,N,A<:AbstractArray,I<:(RangeIndex...,)} <: AbstractArray{T,N}
    parent::A
    indexes::I
    dims::Dims
    strides::Array{Index,1}
    first_index::Index

    #linear indexing constructor
    if N == 1 && length(I) == 1 && A <: Array
        function SubArray(p::A, i::I)
            t = new(p, i, (length(i[1]),))
            if isa(i[1], Index)
                t.strides = [1]
                t.first_index = i[1]
            else
                t.strides = [isa(i[1], Range1) ? 1 : i[1].step]
                t.first_index = i[1].start
            end
            t
        end
    else
        function SubArray(p::A, i::I)
            newdims = Array(Index, 0)
            newstrides = Array(Index, 0)
            newfirst = 1
            pstrides = strides(p)
            for j = 1:length(i)
                if isa(i[j], Index)
                    newfirst += (i[j]-1)*pstrides[j]
                else
                    push(newdims, length(i[j]))
                    #may want to return error if i[j].step <= 0
                    push(newstrides, isa(i[j],Range1) ? pstrides[j] :
                         pstrides[j] * i[j].step)
                    newfirst += (i[j].start-1)*pstrides[j]
                end 
            end
            new(p, i, tuple(newdims...), newstrides, newfirst)
        end
    end
end
#linear indexing sub (may want to rename as slice)
function sub{T,N}(A::Array{T,N}, i::(RangeIndex,))
    SubArray{T,1,typeof(A),typeof(i)}(A, i)
end

function sub{T,N}(A::AbstractArray{T,N}, i::NTuple{N,RangeIndex})
    i = map(j -> isa(j, Index) ? (j:j) : j, i)
    SubArray{T,N,typeof(A),typeof(i)}(A, i)
end
sub(A::AbstractArray, i::RangeIndex...) =
    sub(A, i)
function sub(A::SubArray, i::RangeIndex...)
    j = 1
    newindexes = Array(RangeIndex,length(A.indexes))
    for k = 1:length(A.indexes)
        if isa(A.indexes[k], Index)
            newindexes[k] = A.indexes[k]
        else
            newindexes[k] = A.indexes[k][isa(i[j],Index) ? (i[j]:i[j]) : i[j]]
            j += 1
        end
    end
    sub(A.parent, tuple(newindexes...))
end

function slice{T,N}(A::AbstractArray{T,N}, i::NTuple{N,RangeIndex})
    n = 0
    for j = i; if !isa(j, Index); n += 1; end; end
    SubArray{T,n,typeof(A),typeof(i)}(A, i)
end
slice(A::AbstractArray, i::RangeIndex...) =
    slice(A, i)
function slice(A::SubArray, i::RangeIndex...)
    j = 1
    newindexes = Array(RangeIndex,length(A.indexes))
    for k = 1:length(A.indexes)
        if isa(A.indexes[k], Index)
            newindexes[k] = A.indexes[k]
        else
            newindexes[k] = A.indexes[k][i[j]]
            j += 1
        end
    end
    slice(A.parent, tuple(newindexes...))
end

### rename the old slice function ###
##slice all dimensions of length 1
#slice{T,N}(a::AbstractArray{T,N}) = sub(a, map(i-> i == 1 ? 1 : (1:i), size(a)))
#slice{T,N}(s::SubArray{T,N}) =
#    sub(s.parent, map(i->!isa(i, Index) && length(i)==1 ?i[1] : i, s.indexes))
#
##slice dimensions listed, error if any have length > 1
##silently ignores dimensions that are greater than N
#function slice{T,N}(a::AbstractArray{T,N}, sdims::Int...)
#    newdims = ()
#    for i = 1:N
#        next = 1:size(a, i)
#        for j = sdims
#            if i == j
#                if size(a, i) != 1
#                    error("slice: dimension ", i, " has length greater than 1")
#                end
#                next = 1
#                break
#            end
#        end
#        newdims = tuple(newdims..., next)
#    end
#    sub(a, newdims)
#end 
#function slice{T,N}(s::SubArray{T,N}, sdims::Int...)
#    newdims = ()
#    for i = 1:length(s.indexes)
#        next = s.indexes[i]
#        for j = sdims
#            if i == j
#                if length(next) != 1
#                    error("slice: dimension ", i," has length greater than 1")
#                end
#                next = isa(next, Index) ? next : next.start
#                break
#            end
#        end
#        newdims = tuple(newdims..., next)
#    end
#    sub(s.parent, newdims)
#end
### end commented code ###

size(s::SubArray) = s.dims
ndims{T,N}(s::SubArray{T,N}) = N

copy(s::SubArray) = copy_to(similar(s.parent, size(s)), s)
similar(s::SubArray, T::Type, dims::Dims) = similar(s.parent, T, dims)

ref{T}(s::SubArray{T,0,AbstractArray{T,0}}) = s.parent[]
ref{T}(s::SubArray{T,0}) = s.parent[s.first_index]

ref{T}(s::SubArray{T,1}, i::Int) = s.parent[s.first_index + (i-1)*s.strides[1]]
ref{T}(s::SubArray{T,2}, i::Int, j::Int) =
    s.parent[s.first_index +(i-1)*s.strides[1]+(j-1)*s.strides[2]]

ref(s::SubArray, i::Int) = s[ind2sub(size(s), i)...]

function ref(s::SubArray, is::Int...)
    index = s.first_index
    for i = 1:length(is)
        index += (is[i]-1)*s.strides[i]
    end
    s.parent[index]
end

assign(s::SubArray, v::AbstractArray, i::Int) =
    invoke(assign, (SubArray, Any, Int), s, v, i)
assign(s::SubArray, v, i::Int) = assign(s, v, ind2sub(size(s), i)...)

assign(s::SubArray, v::AbstractArray, i::Int, is::Int...) =
    invoke(assign, (SubArray, Any, Int...), s, v, tuple(i,is...))
assign(s::SubArray, v::AbstractArray, is::Int...) =
    invoke(assign, (SubArray, Any, Int...), s, v, is)
function assign(s::SubArray, v, is::Int...)
    index = s.first_index
    for i = 1:length(is)
        index += (is[i]-1)*s.strides[i]
    end
    s.parent[index] = v
    return s
end

assign{T}(s::SubArray{T,0,AbstractArray{T,0}}, v::AbstractArray) =
    (s.parent[]=v; s)
assign{T}(s::SubArray{T,0,AbstractArray{T,0}},v) =
    (s.parent[]=v; s)
assign{T}(s::SubArray{T,0}, v::AbstractArray) =
    (s.parent[s.first_index]=v; s)
assign{T}(s::SubArray{T,0}, v) =
    (s.parent[s.first_index]=v; s)


assign{T}(s::SubArray{T,1}, v::AbstractArray, i::Int) =
    (s.parent[s.first_index + (i-1)*s.strides[1]] = v; s)
assign{T}(s::SubArray{T,1}, v, i::Int) =
    (s.parent[s.first_index + (i-1)*s.strides[1]] = v; s)
assign{T}(s::SubArray{T,2}, v::AbstractArray, i::Int, j::Int) =
    (s.parent[s.first_index +(i-1)*s.strides[1]+(j-1)*s.strides[2]] = v; s)
assign{T}(s::SubArray{T,2}, v, i::Int, j::Int) =
    (s.parent[s.first_index +(i-1)*s.strides[1]+(j-1)*s.strides[2]] = v; s)

strides(s::SubArray) = tuple(s.strides...)

stride(s::SubArray, i::Int) = s.strides[i]

convert{T}(::Type{Ptr}, x::SubArray{T}) =
    pointer(x.parent) + (x.first_index-1)*sizeof(T)

function pointer{T}(s::SubArray{T}, i::Index)
    is = ind2sub(size(s), i)
    index = s.first_index
    for n = 1:length(is)
        index += (is[n]-1)*s.strides[n]
    end
    return pointer(s.parent, index)
end

summary{T,N}(s::SubArray{T,N}) =
    strcat(dims2string(size(s)), " SubArray of ",
           summary(s.parent))
