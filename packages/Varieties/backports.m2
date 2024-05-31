-----------------------------------------------------------------------------
-- Compatibility with M2 v1.24.05
-----------------------------------------------------------------------------

plurals = new MutableHashTable from {
    "body"       => "bodies",
    "dictionary" => "dictionaries",
    "matrix"     => "matrices",
    "sheaf"      => "sheaves",
    "variety"    => "varieties",
    }
pluralize = s -> demark_" " append(
    drop(ws := separate_" " s, -1),
    if  plurals#?(last ws)
    then plurals#(last ws) else last ws | "s")
pluralsynonym = T -> if T.?synonym then pluralize T.synonym else "objects of class " | toString T

-----------------------------------------------------------------------------

export "isSmooth"
isSmooth = method(TypicalValue => Boolean, Options => true)

-----------------------------------------------------------------------------

applyUniformMethod = (symb, name) -> args -> (
    if #args === 0 then error("expected at least one argument for ", name);
    type := if uniform args then class args#0 else error("expected uniform objects for ", name);
    meth := lookup(symb, type) ?? error("no method for ", name, " of ", pluralsynonym type);
    if (Y := youngest args) =!= null and Y.?cache
    then Y.cache#(symb, args) ??= meth args else meth args)

pullback List := Module => {} >> o -> applyUniformMethod(symbol pullback, "pullback")
pullback(Matrix, Matrix) := Module => {} >> o -> (f, g) -> pullback {f, g}

Matrix.pullback = args -> (
    if not same apply(args, target) then error "expected morphisms with the same target";
    h := concatCols args;
    P := kernel h;
    S := source h;
    P.cache.formation = FunctionApplication (pullback, args);
    P.cache.pullbackMaps = apply(#args,
	i -> map(source args#i, S, S^[i], Degree => - degree args#i) * inducedMap(S, P));
    P)

pushout List := Module => applyUniformMethod(symbol pushout, "pushout")
pushout(Matrix, Matrix) := Module => (f, g) -> pushout {f, g}

Matrix.pushout = args -> (
    if not same apply(args, source) then error "expected morphisms with the same source";
    h := concatRows args;
    P := cokernel h;
    T := target h;
    P.cache.formation = FunctionApplication (pushout, args);
    P.cache.pushoutMaps = apply(#args,
	i -> inducedMap(P, T) * map(T, target args#i, T_[i], Degree => - degree args#i));
    P)


--------------------------------------------------------------------------------
-- factoring of a matrix through another

-- Note: when f and g are endomorphisms, the sources and targets all agree,
-- so we need both functions quotient and quotient' to distinguish them.

-- factor matrices with same targets
Matrix // Matrix := Matrix => (f, g) -> quotient(f, g)
Number // Matrix := RingElement // Matrix := Matrix => (r, g) -> map(source g, target g, map(target g, cover target g, r) // g)
Matrix // Number := Matrix // RingElement := Matrix => (f, r) -> map(target f, source f, f // map(target f, cover target f, r))

-- factor matrices with same sources
Matrix \\ Matrix := Matrix => (g, f) -> quotient'(f, g)
-- commented because they don't seem very meaningful
--Matrix \\ Number := Matrix \\ RingElement := Matrix => (g, r) -> map(source g, target g, g \\ map(cover source g, source g, r))
--Number \\ Matrix := RingElement \\ Matrix := Matrix => (r, f) -> map(target g, source g, map(cover source g, source g, r) \\ f)

quotient(Matrix, Matrix) := Matrix => opts -> (f, g) -> (
    -- given f: A-->C and g: B-->C, then find (f//g): A-->B such that g o (f//g) + r = f
    if target f != target g then error "quotient: expected maps with the same target";
    c := runHooks((quotient, Matrix, Matrix), (opts, f, g), Strategy => opts.Strategy);
    if c =!= null then c else error "quotient: no method implemented for this type of input")

addHook((quotient, Matrix, Matrix), Strategy => Default,
    -- Note: this strategy only works if the remainder is zero, i.e.:
    -- homomorphism' f % image Hom(source f, g) == 0
    -- TODO: should we pass MinimalGenerators => false to Hom and homomorphism'?
    (opts, f, g) -> map(source g, source f, homomorphism(homomorphism' f // Hom(source f, g))))

-- FIXME: this is still causing unreasonable slow downs, e.g. for (large m) // (scalar)
addHook((quotient, Matrix, Matrix), Strategy => "Reflexive", (opts, f, g) -> if f == 0 or isFreeModule source f then (
     L := source f;	     -- result may not be well-defined if L is not free
     M := target f;
     N := source g;
     if M.?generators then (
	  M = cokernel presentation M;	    -- this doesn't change the cover
	  );
     -- now M is a quotient module, without explicit generators
     f' := matrix f;
     g' := matrix g;
     G := (
	 g.cache#"gb for quotient" ??= (
	       if M.?relations 
	       then gb(g' | relations M, ChangeMatrix => true, SyzygyRows => rank source g')
	       else gb(g',               ChangeMatrix => true)));
     map(N, L, f' // G, 
	  Degree => degree f' - degree g'  -- set the degree in the engine instead
	  )))

addHook((quotient, Matrix, Matrix), Strategy => InexactField, (opts, f, g) ->
    if instance(ring target f, InexactField)
    -- TODO: c.f. https://github.com/Macaulay2/M2/issues/3252
    and numRows g === numColumns g
    and isFreeModule source g
    and isFreeModule source f
    then solve(g, f))

addHook((quotient, Matrix, Matrix), Strategy => ZZ, (opts, f, g) ->
    if isQuotientOf(ZZ, ring target f)
    and isFreeModule source g
    and isFreeModule source f
    then solve(g, f))

quotient'(Matrix, Matrix) := Matrix => -* opts -> *- (f, g) -> (
    -- given f: A-->C and g: A-->B, then finds (g\\f): B-->C such that (g\\f) o g + r = f
    if source f != source g then error "quotient': expected maps with the same source";
    c := runHooks((quotient', Matrix, Matrix), (options quotient, f, g));
    if c =!= null then c else error "quotient': no method implemented for this type of input")

addHook((quotient', Matrix, Matrix), Strategy => Default,
    -- Note: this strategy only works if the remainder is zero, i.e.:
    -- homomorphism' f % image Hom(g, target f) == 0
    -- TODO: should we pass MinimalGenerators => false to Hom and homomorphism'?
    (opts, f, g) -> map(target f, target g, homomorphism(homomorphism' f // Hom(g, target f))))

addHook((quotient', Matrix, Matrix), Strategy => "Reflexive",
    (opts, f, g) -> if all({source f, target f, source g, target g}, isFreeModule) then dual quotient(dual f, dual g, opts))


end--
restart
loadPackage("Truncations", Reload => true)
loadPackage("Varieties", Reload => true)
check Varieties