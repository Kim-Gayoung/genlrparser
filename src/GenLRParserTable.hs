--------------------------------------------------------------------------------
-- An LR Parser Table Generator
-- 
-- Copyright(c) 2013 Kwanghoon Choi. All rights reserved.
--
-- Usage:
--  $ ghci GenLRParserTable
--  *Main> prParseTable (calcLR1ParseTable g1)
--  *Main> prLALRParseTable (calcLALRParseTable g1)
--
--  * let (items,_,lkhtbl,gotos) = calcLR0ParseTable g1 
--    in do { prItems items; prGtTbl gotos; prLkhTable lkhtbl }
--
--  * closure g4 [Item (ProductionRule "S'" [Nonterminal "S"]) 0 [Symbol (Terminal "")]]
--------------------------------------------------------------------------------

module GenLRParserTable where

import Data.List
import Data.Maybe
import System.Environment (getArgs)

import CFG
import ParserTable

_main = do
  args <- getArgs
  mapM f args
  where
    f file = do
      grammar <- readFile file
      let cfg = read grammar :: CFG
      -- let sprime = startNonterminal cfg 
      prParseTable (calcEfficientLALRParseTable cfg)
      -- let (items,_,lkhtbl,gotos) = calcEfficientLALRParseTable cfg
      -- let (lkhtbl1,lkhtbl2) = lkhtbl
      -- prItems items
      -- prGtTbl gotos
      -- prSpontaneous lkhtbl1
      -- prPropagate lkhtbl2 

__main g = do
  prParseTable (calcEfficientLALRParseTable g)
  -- let kernelitems = map (filter (isKernel (startNonterminal g))) items
  -- let (lkhtbl1,lkhtbl2) = lkhtbl
  -- prItems items
  -- prGtTbl gotos
  -- prItems kernelitems
  -- prSpontaneous lkhtbl1
  -- prPropagate lkhtbl2 
  -- putStrLn ""
  -- prItems (computeLookaheads lkhtbl1 lkhtbl2 kernelitems)
  -- let f (x,y) = do { putStrLn (show x); prItem y; putStrLn "" }
  -- mapM_ f $ [ (item, closure g [Item prule dot [sharpSymbol]])
  --           | items <- kernelitems
  --           , item@(Item prule dot _) <- items ]
    
--
indexPrule :: AUGCFG -> ProductionRule -> Int
indexPrule augCfg prule = indexPrule' prules prule 0
  where
    CFG _ prules = augCfg
  
indexPrule' []     prule n = error ("indexPrule: not found " ++ show prule)
indexPrule' (r:rs) prule n = 
  if r == prule then n else indexPrule' rs prule (n+1)
                            
prPrules ps = prPrules' ps 0

prPrules' [] n = return ()
prPrules' (prule:prules) n = 
  do putStrLn (show n ++ ": " ++ show prule)
     prPrules' prules (n+1)
      
--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------
symbols :: CFG -> [Symbol]
symbols (CFG start prules) 
  = [Nonterminal x | Nonterminal x <- syms] ++
    [Terminal x    | Terminal x    <- syms]
  where
    f (ProductionRule x syms) = Nonterminal x:syms
    syms = nub (Nonterminal start : concat (map f prules))

--
first :: [(Symbol, [ExtendedSymbol])] -> Symbol -> [ExtendedSymbol]
first tbl x = case (lookup x tbl) of
  Nothing -> [Symbol x]
  -- Nothing -> if x == Terminal "#" 
  --             then [Symbol x] 
  --             else error (show x ++ " not in " ++ show tbl)
  Just y -> y

first_ :: [(Symbol, [ExtendedSymbol])] -> [Symbol] -> [ExtendedSymbol]
first_ tbl []     = []
first_ tbl (z:zs) = let zRng = first tbl z in
  if elem Epsilon zRng 
  then union ((\\) zRng [Epsilon]) (first_ tbl zs)
  else zRng
                                                            
extFirst :: [(Symbol, [ExtendedSymbol])] -> ExtendedSymbol -> [ExtendedSymbol]
extFirst tbl (Symbol x)    = first tbl x
extFirst tbl (EndOfSymbol) = [EndOfSymbol]
extFirst tbl (Epsilon)     = error "extFirst_ : Epsilon"

extFirst_ :: [(Symbol, [ExtendedSymbol])] -> [ExtendedSymbol] -> [ExtendedSymbol]
extFirst_ tbl []     = []
extFirst_ tbl (z:zs) = let zRng = extFirst tbl z in
  if elem Epsilon zRng 
  then union ((\\) zRng [Epsilon]) (extFirst_ tbl zs)
  else zRng
  
--
calcFirst :: CFG -> [(Symbol, [ExtendedSymbol])]
calcFirst cfg = calcFirst' cfg (initFirst cfg) (symbols cfg)
    
initFirst cfg =
  let syms         = symbols cfg
      CFG _ prules = cfg
  in [(Terminal x, [Symbol (Terminal x)]) 
     | Terminal x <- syms]
     ++    
     [(Nonterminal x, [Epsilon | ProductionRule y [] <- prules, x == y])
     | Nonterminal x <- syms]

calcFirst' cfg currTbl syms =
  let (isChanged, nextFst) = calcFirst'' cfg currTbl syms in
  if isChanged then calcFirst' cfg nextFst syms else currTbl
                                                 

calcFirst'' cfg tbl [] 
  = (False, [])
calcFirst'' cfg tbl (Terminal x:therest)
  = calcFirst''' cfg tbl (False, (Terminal x, first tbl (Terminal x))) therest
calcFirst'' cfg tbl (Nonterminal x:therest) 
  = calcFirst''' cfg tbl (ischanged, (Nonterminal x, rng)) therest
    where
      CFG start prules = cfg
      
      addendum   = f [zs | ProductionRule y zs <- prules, x == y]
      currRng    = first tbl (Nonterminal x)
      ischanged  = (\\) addendum currRng /= []
      rng        = union addendum currRng
      
      f []       = []
      f (zs:zss) = union (first_ tbl zs) (f zss)
                   
calcFirst''' cfg tbl (bool1, oneupdated) therest =
  let (bool2, therestupdated) = calcFirst'' cfg tbl therest in
  (bool1 || bool2, oneupdated:therestupdated)


--
follow :: [(Symbol, [ExtendedSymbol])] -> Symbol -> [ExtendedSymbol]
follow tbl x = case lookup x tbl of
  Nothing -> error (show x ++ " : " ++ show tbl)
  Just z  -> z

--
calcFollow :: CFG -> [(Symbol, [ExtendedSymbol])]
calcFollow cfg = calcFollow' (calcFirst cfg) prules (initFollow cfg) 
  where CFG _ prules = cfg

initFollow cfg = 
  let CFG start prules = cfg
  in  [(Nonterminal x, [EndOfSymbol | x == start])
      | Nonterminal x <- symbols cfg]
      
calcFollow' fstTbl prules currTbl = 
  let (isChanged, nextFlw) = calcFollow'' fstTbl currTbl prules False in
  if isChanged then calcFollow' fstTbl prules nextFlw else currTbl
                                                      
calcFollow'' fstTbl flwTbl []                            b = (b, flwTbl)
calcFollow'' fstTbl flwTbl (ProductionRule y zs:therest) b =
  calcFollow'' fstTbl tbl' therest b'
  where
    (b',tbl') = f zs flwTbl b
    
    _y             = Nonterminal y
    
    f []                 tbl b = (b, tbl)
    f [Terminal z]       tbl b = (b, tbl)
    f [Nonterminal z]    tbl b =
      let flwZ = follow flwTbl (Nonterminal z)
          zRng = union flwZ (follow flwTbl _y)
          isChanged = (\\) zRng flwZ /= []
      in  (isChanged, upd (Nonterminal z) zRng tbl)
    f (Terminal z:zs)    tbl b = f zs tbl b
    f (Nonterminal z:zs) tbl b =
      let fstZS = first_ fstTbl zs
          flwZ  = follow flwTbl (Nonterminal z)
          zRng  = union (follow flwTbl (Nonterminal z))
                    (union ((\\) fstZS [Epsilon])
                      (if elem Epsilon fstZS 
                       then follow flwTbl _y
                       else []))
          isChanged = (\\) zRng flwZ /= []
      in  f zs (upd (Nonterminal z) zRng tbl) isChanged
    
    upd z zRng tbl = [if z == x then (x, zRng) else (x,xRng) | (x,xRng) <- tbl]
    
--     
closure :: AUGCFG -> Items -> Items
closure augCfg items = 
  if isChanged 
  then closure augCfg itemsUpdated  -- loop over items
  else items
  where
    CFG s prules = augCfg
    (isChanged, itemsUpdated) 
      = closure' (calcFirst augCfg) prules items items False
                       
                  
closure' fstTbl prules cls [] b = (b, cls)
closure' fstTbl prules cls (Item (ProductionRule x alphaBbeta) d lookahead:items) b = 
  if _Bbeta /= []
  then f cls b prules
  else closure' fstTbl prules cls items b
  where
    _Bbeta = drop d alphaBbeta
    _B     = head _Bbeta
    beta   = tail _Bbeta
    
    -- loop over production rules
    f cls b [] = closure' fstTbl prules cls items b
    f cls b (r@(ProductionRule y gamma):rs) = 
      if _B == Nonterminal y
      then (if lookahead == [] 
            then flrzero cls b r rs -- closure for LR(0)
            else g cls b r rs (extFirst_ fstTbl (map Symbol beta ++ lookahead))) -- closure for LR(1)
      else f cls b rs

    flrzero cls b r rs = 
      let item = Item r 0 []
      in  if elem item cls then f cls b rs 
          else f (cls ++ [item]) True rs

    -- loop over terminal symbols
    g cls b r rs [] = f cls b rs
    g cls b r rs (Symbol (Terminal t) : fstSyms) =
      let item = Item r 0 [Symbol (Terminal t)]
      in  if elem item cls 
          then g cls b r rs fstSyms 
          else g (cls++[item]) True r rs fstSyms
    g cls b r rs (Symbol (Nonterminal t) : fstSyms) = g cls b r rs fstSyms
    g cls b r rs (EndOfSymbol : fstSyms) = 
      let item = Item r 0 [EndOfSymbol]
      in  if elem item cls 
          then g cls b r rs fstSyms 
          else g (cls++[item]) True r rs fstSyms
    g cls b r rs (Epsilon : fstSyms) = error "closure: Epsilon"
    
--    
calcLR0Items :: AUGCFG -> Itemss
calcLR0Items augCfg = calcItems' augCfg syms iss0
  where 
    CFG _S prules = augCfg
    i0   = Item (head prules) 0 []  -- The 1st rule : S' -> S.
    is0  = closure augCfg [i0]
    iss0 = [ is0 ]

    syms = (\\) (symbols augCfg) [Nonterminal _S]
    -- syms = [ sym | sym <- symbols augCfg, sym /= Nonterminal _S]

calcLR1Items :: AUGCFG -> Itemss
calcLR1Items augCfg = calcItems' augCfg syms iss0
  where 
    CFG _S prules = augCfg
    i0   = Item (head prules) 0 [EndOfSymbol]  -- The 1st rule : S' -> S.
    is0  = closure augCfg [i0]
    iss0 = [ is0 ]

    syms = (\\) (symbols augCfg) [Nonterminal _S]
    -- syms = [ sym | sym <- symbols augCfg, sym /= Nonterminal _S]
  
calcItems' augCfg syms currIss  =
  if isUpdated
  then calcItems' augCfg syms nextIss
  else currIss
  where
    (isUpdated, nextIss) = f currIss False currIss
    
    -- loop over sets of items
    f []       b currIss = (b, currIss)
    f (is:iss) b currIss = g is iss b currIss syms
    
    -- loop over symbols
    g is iss b currIss []     = f iss b currIss
    g is iss b currIss (x:xs) = 
      let is' = goto augCfg is x
      in  if is' == [] || elemItems is' currIss 
          then g is iss b currIss xs 
          else g is iss True (currIss ++ [is']) xs

elemItems :: Items -> Itemss -> Bool       
elemItems is0 []       = False
elemItems is0 (is:iss) = eqItems is0 is || elemItems is0 iss
                         
eqItems :: Items -> Items -> Bool                         
eqItems is1 is2 = (\\) is1 is2 == [] && (\\) is2 is1 == []

indexItem :: String -> Itemss -> Items -> Int
indexItem loc items item = indexItem' loc items item 0

indexItem' loc (item1:items) item2 n
  = if eqItems item1 item2 then n else indexItem' loc items item2 (n+1)
indexItem' loc [] item n = error ("indexItem: not found " ++ show item ++ " at " ++ loc)

goto :: AUGCFG -> Items -> Symbol -> Items
goto augCfg items x = closure augCfg itemsOverX
  where
    itemsOverX = [ Item (ProductionRule z alphaXbeta) (j+1) y
                 | Item (ProductionRule z alphaXbeta) j     y <- items
                 , let _Xbeta = drop j alphaXbeta
                 , _Xbeta /= []
                 , x == head _Xbeta ]
                 


--------------------------------------------------------------------------------
-- Canonical LR Parser
--------------------------------------------------------------------------------
sharp = Terminal "#"  -- a special terminal symbol
sharpSymbol = Symbol sharp

calcEfficientLALRParseTable :: AUGCFG -> (Itemss, ProductionRules, ActionTable, GotoTable)
calcEfficientLALRParseTable augCfg = (lr1items, prules, actionTable, gotoTable) -- (lr0items, prules, lkhTable, gotoTable)
  where
    CFG _S' prules = augCfg 
    lr0items = calcLR0Items augCfg 
    lr0kernelitems = map (filter (isKernel (startNonterminal augCfg))) lr0items
    syms = (\\) (symbols augCfg) [Nonterminal _S']

    terminalSyms    = [Terminal x    | Terminal x    <- syms]
    nonterminalSyms = [Nonterminal x | Nonterminal x <- syms]

    lr0GotoTable = nub
      [ (from, h, to)
      | item1 <- lr0items
      , Item (ProductionRule y ys) j lookahead <- item1
      , let from = indexItem "lr0GotoTable(from)" lr0items item1
      , let ri   = indexPrule augCfg (ProductionRule y ys)
      , let ys' = drop j ys
      , let h = head ys'
      , let to = indexItem "lr0GotoTable(to)" lr0items (goto augCfg item1 h)
      , ys' /= []
      -- , isTerminal h == False
      ]

    lkhTable = 
      let (ass, bss) = unzip lkhTable' in (nub (concat ass), nub (concat bss))

    lkhTable' =
      [ ( [ (Item (head prules) 0 [], [EndOfSymbol])], []) ] 
      ++
      [ ( [ (Item prule2 dot2 [], lookahead1) 
          | lookahead1 /= [sharpSymbol] ]
        , [ (Item pruleyys dot0 [], fromIndex, Item prule2 dot2 [], toIndex) 
          | lookahead1 == [sharpSymbol] ]
        )
      | (fromIndex, lr0kernelitem) <- zip [0..] lr0kernelitems
      , item@(Item pruleyys dot0 _) <- lr0kernelitem 
      , let lr1items = closure augCfg [Item pruleyys dot0 [sharpSymbol]]
      , Item prule1@(ProductionRule lhs rhs) dot1 lookahead1 <- lr1items
      , let therestrhs = drop dot1 rhs 
      , therestrhs /= []
      , let symbolx = head therestrhs
      , let toIndexes = [t | (f,x,t) <- lr0GotoTable, f==fromIndex, x==symbolx ]
      , toIndexes /= []
      , let toIndex = head toIndexes
      , let gotoIX = lr0kernelitems !! toIndex
      , Item prule2 dot2 lookahead2 <- gotoIX
      ]

    head_ i [] = error ("head_: " ++ show i)
    head_ i (x:xs) = x

    lr1kernelitems = computeLookaheads (fst lkhTable) (snd lkhTable) 
                      (map (filter (isKernel (startNonterminal augCfg))) lr0items)

    lr1items = map (closure augCfg) lr1kernelitems

    (actionTable, gotoTable) = calcLR1ActionGotoTable augCfg lr1items



type Lookahead = [ExtendedSymbol] 
type SpontaneousLookahead = [(Item, Lookahead)]
type PropagateLookahead = [(Item, Int, Item, Int)]

computeLookaheads :: SpontaneousLookahead -> PropagateLookahead -> Itemss -> Itemss
computeLookaheads splk prlk lr0kernelitemss = lr1kernelitemss
  where
    lr1kernelitemss = 
      [ concat [ if lookaheads == []  then [Item prule dot []]
          else [ Item prule dot lookahead | lookahead <- lookaheads ] 
          | (Item prule dot _, lookaheads) <- itemlks ]
      | itemlks <- lr1kernelitemlkss ]

    initLr1kernelitemlkss = init lr0kernelitemss
    lr1kernelitemlkss = snd (unzip (prop (zip [0..] initLr1kernelitemlkss)))

    init [] = []
    init (items:itemss) = init' items : init itemss 
    
    init' [] = []
    init' (item:items) = (item, init'' item [] splk ) : init' items

    init'' itembase lookaheads [] = lookaheads 
    init'' itembase lookaheads ((splkitem,lookahead):splkitems) = 
      if itembase == splkitem 
      then init'' itembase (lookaheads ++ [lookahead]) splkitems 
      else init'' itembase lookaheads splkitems 

    prop ilr1kernelitemlkss = 
      let itemToLks = collect ilr1kernelitemlkss prlk 
          (changed, ilr1kernelitemlkss') = 
             copy ilr1kernelitemlkss itemToLks
      in  if changed then prop ilr1kernelitemlkss'
          else ilr1kernelitemlkss

    collect ilr1kernelitemlkss [] = []
    collect ilr1kernelitemlkss (itemFromTo:itemFromTos) = 
      let (itemFrom, fromIndex, itemTo, toIndex) = itemFromTo 
          lookaheads = collect' itemFrom fromIndex [] ilr1kernelitemlkss 
      in (itemTo, toIndex, lookaheads) : collect ilr1kernelitemlkss itemFromTos

    collect' itemFrom fromIndex lookaheads [] = lookaheads
    collect' itemFrom fromIndex lookaheads ((index, iitemlks):iitemlkss) = 
      if fromIndex == index 
      then collect' itemFrom fromIndex 
            (collect'' itemFrom lookaheads iitemlks) iitemlkss
      else collect' itemFrom fromIndex lookaheads iitemlkss

    collect'' itemFrom lookaheads [] = lookaheads
    collect'' itemFrom lookaheads ((Item prule dot _, lks):itemlks) = 
      let Item pruleFrom dotFrom _ = itemFrom
          lookaheads' = if pruleFrom == prule && dotFrom == dot 
                        then lks else []
      in collect'' itemFrom (lookaheads ++ lookaheads') itemlks
      
    copy iitemlkss [] = (False, iitemlkss)
    copy iitemlkss (itemToLookahead:itemToLookaheads) = 
      let (changed1, iitemlkss1) = copy' iitemlkss itemToLookahead
          (changed2, iitemlkss2) = copy iitemlkss1 itemToLookaheads 
      in  (changed1 || changed2, iitemlkss2) 

    copy' [] itemToLookahead = (False, [])
    copy' ((index,itemlks):iitemlkss) itemToLookahead = 
      let (changed1, itemlks1) = copy'' index itemlks itemToLookahead 
          (changed2, itemlkss2) = copy' iitemlkss itemToLookahead
      in  (changed1 || changed2, (index,itemlks1):itemlkss2)

    copy'' index [] itemToLookahead = (False, [])
    copy'' index (itemlk:itemlks) itemToLookahead = 
      let (Item prule1 dot1 _, toIndex, lookahead1) = itemToLookahead
          (Item prule2 dot2 l2, lookahead2) = itemlk  
          lookahead2' = 
            if prule1 == prule2 && dot1 == dot2 
              && index == toIndex
              && lookahead1 \\ lookahead2 /= []
              then nub (lookahead1 ++ lookahead2) else lookahead2
          changed1 = lookahead2' /= lookahead2
          itemlk1 = (Item prule2 dot2 l2, lookahead2')
          (changed2, itemlks2) = copy'' index itemlks itemToLookahead
      in (changed1 || changed2, itemlk1:itemlks2) 


prLkhTable [] = return ()
prLkhTable ((spontaneous, propagate):lkhTable) = do 
  prSpontaneous spontaneous
  prPropagate propagate
  prLkhTable lkhTable

prSpontaneous [] = return ()
prSpontaneous ((item, [lookahead]):spontaneous) = do 
  putStr (show item)
  putStr ", "
  putStrLn (show lookahead)
  prSpontaneous spontaneous

prPropagate [] = return ()
prPropagate ((from, fromIndex, to, toIndex):propagate) = do 
  putStr (show from ++ " at " ++ show fromIndex)
  putStr " -prop-> "
  putStr (show to ++ " at " ++ show toIndex) 
  putStrLn ""
  prPropagate propagate

calcLR1ParseTable :: AUGCFG -> (Itemss, ProductionRules, ActionTable, GotoTable)
calcLR1ParseTable augCfg = (items, prules, actionTable, gotoTable)
  where
    CFG _S' prules = augCfg
    items = calcLR1Items augCfg
    (actionTable, gotoTable) = calcLR1ActionGotoTable augCfg items 

calcLR1ActionGotoTable augCfg items = (actionTable, gotoTable)
  where
    CFG _S' prules = augCfg
    -- items = calcLR1Items augCfg
    -- syms  = (\\) (symbols augCfg) [Nonterminal _S']
    
    -- terminalSyms    = [Terminal x    | Terminal x    <- syms]
    -- nonterminalSyms = [Nonterminal x | Nonterminal x <- syms]
    
    f :: [(ActionTable,GotoTable)] -> (ActionTable, GotoTable)
    f l = case unzip l of (fst,snd) -> (g [] (concat fst), h [] (concat snd))
                          
    g actTbl [] = actTbl
    g actTbl ((i,x,a):triples) = 
      let bs = [a' == a | (i',x',a') <- actTbl, i' == i && x' == x ] in
      if length bs == 0
      then g (actTbl ++ [(i,x,a)]) triples
      else if and bs 
           then g actTbl triples 
           else error ("Conflict: " 
                       ++ show (i,x,a) 
                       ++ " " 
                       ++ show actTbl)
                
    h :: GotoTable -> GotoTable -> GotoTable
    h gtTbl [] = gtTbl
    h gtTbl ((i,x,j):triples) =
      let bs = [j' == j | (i',x',j') <- gtTbl, i' == i && x' == x ] in
      if length bs == 0
      then h (gtTbl ++ [(i,x,j)]) triples
      else if and bs
           then h gtTbl triples
           else error ("Conflict: "
                       ++ show (i,x,j)
                       ++ " "
                       ++ show gtTbl)
    
    (actionTable, gotoTable) = f
      [ if ys' == []
        then if y == _S' 
             then ([(from, a, Accept)   ], []) 
             else ([(from, a, Reduce ri)], [])
        else if isTerminal h 
             then ([(from, Symbol h, Shift to) ], [])
             else ([]                    , [(from, h, to)])
      | item1 <- items
      , Item (ProductionRule y ys) j [a] <- item1
      , let from = indexItem "lr1ActionGotoTable(from)"  items item1
      , let ri   = indexPrule augCfg (ProductionRule y ys)
      , let ys' = drop j ys
      , let h = head ys'
      , let to = indexItem "lr1ActionGotoTable(to)" items (goto augCfg item1 h)
      ]
      
prParseTable (items, prules, actTbl, gtTbl) =
  do putStrLn (show (length items) ++ " states")
     prItems items
     putStrLn ""
     prPrules prules
     putStrLn ""
     prActTbl actTbl
     putStrLn ""
     prGtTbl gtTbl
     
prLALRParseTable (items, prules, iss, lalrActTbl, lalrGtTbl) =
  do putStrLn (show (length items) ++ " states")
     prItems items
     putStrLn ""
     prPrules prules
     putStrLn ""
     putStrLn (show (length iss) ++ " states")
     prStates iss
     putStrLn ""
     prActTbl lalrActTbl
     putStrLn ""
     prGtTbl lalrGtTbl
     
prStates [] = return ()     
prStates (is:iss) =
  do putStrLn (show is)
     prStates iss
     
--------------------------------------------------------------------------------
-- LALR Parser 
--------------------------------------------------------------------------------

calcLALRParseTable :: AUGCFG -> 
                      (Itemss, ProductionRules, [[Int]], LALRActionTable
                      , LALRGotoTable)
calcLALRParseTable augCfg = (itemss, prules, iss, lalrActTbl, lalrGtTbl)
  where
    (itemss, prules, actTbl, gtTbl) = calcLR1ParseTable augCfg
    itemss' = nubBy eqCore itemss
    iss     = [ [i | (i, items) <- zip [0..] itemss, eqCore items items']
              | items' <- itemss'] 
              
    lalrActTbl = [ (is, x, lalrAct)
                 | is <- iss
                 , let syms = nub [ y | i <- is, (j, y, a) <- actTbl, i == j ]
                 , x <- syms
                 , let lalrAct = actionCheck $
                         nub [ toLalrAction iss a
                             | i <- is
                             , let r = lookupTable i x actTbl
                             , isJust r
                             , let Just a = r ]  ]

    lalrGtTbl  = [ (is, x, js) 
                 | is <- iss
                 , let syms = nub [ y | i <- is, (j, y, k) <- gtTbl, i == j]
                 , x <- syms
                 , let js = stateCheck $ 
                         nub [ toIs iss j'
                             | i <- is
                             , (i', x', j') <- gtTbl
                             , i==i' && x==x' ]  ]
    
eqCore :: Items -> Items -> Bool    
eqCore items1 items2 = subsetCore items1 items2 && subsetCore items2 items1

subsetCore []             items2 = True
subsetCore (item1:items1) items2 = elemCore item1 items2 && subsetCore items1 items2
  
elemCore (Item prule1 i1 a) [] = False
elemCore (Item prule1 i1 a) (Item prule2 i2 _:items) = 
  if prule1 == prule2 && i1 == i2 
  then True else elemCore (Item prule1 i1 a) items
    
toLalrAction :: [[Int]] -> Action -> LALRAction
toLalrAction iss (Shift i)  = LALRShift (toIs iss i)
toLalrAction iss (Reduce i) = LALRReduce i
toLalrAction iss (Accept)   = LALRAccept
toLalrAction iss (Reject)   = LALRReject

toIs []       i = error ("toIs: not found" ++ show i)
toIs (is:iss) i = if elem i is then is else toIs iss i

actionCheck :: [LALRAction] -> LALRAction
actionCheck [a] = a
actionCheck as  = error ("LALR Action Conflict: " ++ show as)

stateCheck :: [[Int]] -> [Int]
stateCheck [is] = is
stateCheck iss  = error ("LALR State Conflict: " ++ show iss)
