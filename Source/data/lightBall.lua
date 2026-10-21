-- Explicit GenV acquisition extension; no Blue ID, price, shop or guessed resale.
assert(ItemData.definitions.lightBall==nil and ItemData.bySymbol.LIGHT_BALL==nil,"duplicate-Light-Ball-item-definition")
ItemData.definitions.lightBall={name="LIGHT BALL",sourceName="Light Ball",symbol="LIGHT_BALL",
    gen5Id=236,pokeApiId=213,keyItem=false,category="held",effect="unsupported"}
ItemData.bySymbol.LIGHT_BALL="lightBall"
