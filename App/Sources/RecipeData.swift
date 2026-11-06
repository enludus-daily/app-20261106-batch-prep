// 作り置きのレシピ（手で書いたもの）。書式は Recipes.swift の RecipeParser。
// 日持ちは冷蔵のめやす。時間は家庭の台所で作るめやす（段取りの計算に使う）。
// 1〜24 は無料、25 以降は Pro（お弁当・冷凍の素・汁の素・漬けの束と、週末のごちそう）。
enum RecipeData {
    static let text = """
# ---- 主菜（無料） ----
R|nikujaga|肉じゃが|main|4|4|0|0
I|じゃがいも|3|個|veg
I|玉ねぎ|1|個|veg
I|にんじん|1|本|veg
I|豚こま切れ肉|200|g|meat
I|しょうゆ|3|大さじ|season
I|砂糖|2|大さじ|season
I|みりん|2|大さじ|season
S|野菜の皮をむいて、ひと口大に切る|10|h|-
S|肉と野菜を炒める|5|h|burner
S|水と調味料を入れ、落としぶたで煮る|20|w|burner
S|火を止めて味を含ませる|15|w|-

R|chikuzen|筑前煮|main|4|5|0|0
I|鶏もも肉|1|枚|meat
I|れんこん|150|g|veg
I|ごぼう|1|本|veg
I|にんじん|1|本|veg
I|干ししいたけ|4|枚|dry
I|しょうゆ|3|大さじ|season
I|砂糖|2|大さじ|season
S|干ししいたけを水で戻す|20|w|-
S|根菜と鶏肉を乱切りにする|12|h|-
S|鶏肉と根菜を炒める|5|h|burner
S|戻し汁と調味料でふたをして煮る|20|w|burner
S|ふたを取り、煮汁をからめる|5|h|burner

R|nanbanzuke|鶏の南蛮漬け|main|4|4|0|0
I|鶏むね肉|1|枚|meat
I|玉ねぎ|0.5|個|veg
I|にんじん|0.5|本|veg
I|片栗粉|3|大さじ|season
I|酢|4|大さじ|season
I|砂糖|2|大さじ|season
I|しょうゆ|2|大さじ|season
S|野菜を薄切りにして南蛮酢を合わせる|8|h|-
S|鶏肉をそぎ切りにして粉をまぶす|6|h|-
S|揚げ焼きにする|10|h|burner
S|熱いうちに南蛮酢に漬ける|30|w|-

R|mini-hamburg|ミニハンバーグ|main|8|3|1|0
I|合いびき肉|300|g|meat
I|玉ねぎ|0.5|個|veg
I|卵|1|個|egg
I|パン粉|0.5|カップ|dry
I|ケチャップ|3|大さじ|season
I|ソース|2|大さじ|season
S|玉ねぎをみじん切りにする|5|h|-
S|玉ねぎをレンジで加熱する|3|w|micro
S|玉ねぎを冷ます|10|w|-
S|タネをこねて小さく丸める|10|h|-
S|両面を焼いてソースをからめる|15|h|burner

R|shogayaki|豚のしょうが焼き|main|4|3|1|0
I|豚ロース薄切り肉|300|g|meat
I|玉ねぎ|1|個|veg
I|しょうが|1|かけ|veg
I|しょうゆ|3|大さじ|season
I|みりん|2|大さじ|season
S|玉ねぎを切り、しょうがをすりおろしてたれを合わせる|6|h|-
S|肉をたれに漬ける|15|w|-
S|玉ねぎと肉を炒める|8|h|burner

R|saba-miso|さばの味噌煮|main|4|3|0|0
I|さば|2|切れ|meat
I|しょうが|1|かけ|veg
I|みそ|3|大さじ|season
I|砂糖|2|大さじ|season
I|酒|50|ml|season
S|さばに切り込みを入れ、湯をかけて臭みを取る|6|h|burner
S|煮汁でふたをして煮る|15|w|burner
S|みそを溶き入れて煮詰める|5|h|burner

R|tori-chashu|鶏チャーシュー|main|4|4|1|0
I|鶏もも肉|2|枚|meat
I|長ねぎ|1|本|veg
I|しょうゆ|4|大さじ|season
I|砂糖|2|大さじ|season
I|酒|50|ml|season
S|鶏肉を巻いてたこ糸でしばる|8|h|-
S|転がしながら焼き色をつける|6|h|burner
S|たれでふたをして煮る|25|w|burner
S|たれに漬けたまま冷ます|30|w|-

R|sake-yakibitashi|鮭の焼きびたし|main|4|3|1|0
I|生鮭|4|切れ|meat
I|長ねぎ|1|本|veg
I|めんつゆ|80|ml|season
S|鮭とねぎを食べやすく切る|4|h|-
S|グリルで焼く|12|w|oven
S|熱いうちにつゆに漬ける|20|w|-

R|tori-ham|鶏ハム|main|4|4|0|0
I|鶏むね肉|2|枚|meat
I|塩|1|小さじ|season
I|砂糖|1|小さじ|season
S|鶏肉に塩と砂糖をすり込む|5|h|-
S|下味をなじませる|30|w|-
S|ラップで巻いて2分ゆでる|5|w|burner
S|ふたをして余熱で火を通す|40|w|-

R|teba-daikon|手羽元と大根の煮物|main|4|4|0|0
I|手羽元|8|本|meat
I|大根|0.5|本|veg
I|しょうゆ|3|大さじ|season
I|砂糖|2|大さじ|season
S|大根を厚めのいちょう切りにする|6|h|-
S|大根をレンジで下ゆでする|6|w|micro
S|手羽元に焼き色をつける|6|h|burner
S|大根を入れて煮汁で煮る|25|w|burner

# ---- 副菜（無料） ----
R|kinpira|きんぴらごぼう|side|4|5|1|0
I|ごぼう|1|本|veg
I|にんじん|0.5|本|veg
I|ごま油|1|大さじ|season
I|しょうゆ|2|大さじ|season
I|砂糖|1|大さじ|season
I|白ごま|1|大さじ|dry
S|ごぼうとにんじんを細切りにする|10|h|-
S|ごま油で炒める|5|h|burner
S|調味料を入れて炒め煮にする|5|h|burner

R|hijiki|ひじきの煮物|side|4|5|1|0
I|乾燥ひじき|20|g|dry
I|にんじん|0.5|本|veg
I|油揚げ|1|枚|egg
I|大豆の水煮|100|g|dry
I|しょうゆ|2|大さじ|season
I|砂糖|1|大さじ|season
S|ひじきを水で戻す|20|w|-
S|にんじんと油揚げを細く切る|5|h|-
S|具を炒める|3|h|burner
S|汁気がなくなるまで煮る|12|w|burner

R|horenso|ほうれん草のおひたし|side|4|3|0|0
I|ほうれん草|1|束|veg
I|かつお節|1|袋|dry
I|しょうゆ|1|大さじ|season
I|だし|100|ml|season
S|ほうれん草をゆでる|4|h|burner
S|水にさらして絞り、切る|4|h|-
S|だしに浸す|20|w|-

R|ninjin-rapee|にんじんラペ|side|4|5|0|0
I|にんじん|2|本|veg
I|酢|2|大さじ|season
I|オリーブ油|2|大さじ|season
I|はちみつ|1|大さじ|season
S|にんじんをせん切りにする|8|h|-
S|調味料であえる|2|h|-
S|味をなじませる|30|w|-

R|kabocha-ni|かぼちゃの煮物|side|4|4|1|0
I|かぼちゃ|0.25|個|veg
I|しょうゆ|1.5|大さじ|season
I|砂糖|1.5|大さじ|season
I|みりん|1|大さじ|season
S|かぼちゃを切って面取りする|6|h|-
S|煮汁でふたをして煮る|15|w|burner
S|冷まして味を含ませる|15|w|-

R|broccoli-goma|ブロッコリーのごまあえ|side|4|3|0|0
I|ブロッコリー|1|株|veg
I|すりごま|2|大さじ|dry
I|しょうゆ|1|大さじ|season
I|砂糖|1|大さじ|season
S|小房に分ける|4|h|-
S|レンジで加熱する|3|w|micro
S|ごまあえにする|3|h|-

R|nasu-bitashi|なすの揚げびたし|side|4|4|0|0
I|なす|4|本|veg
I|しょうが|1|かけ|veg
I|めんつゆ|100|ml|season
S|なすを切る|4|h|-
S|揚げ焼きにする|10|h|burner
S|めんつゆに漬ける|30|w|-

R|kiriboshi|切り干し大根の煮物|side|4|5|1|0
I|切り干し大根|40|g|dry
I|にんじん|0.5|本|veg
I|油揚げ|1|枚|egg
I|しょうゆ|2|大さじ|season
I|砂糖|1|大さじ|season
S|切り干し大根を水で戻す|15|w|-
S|にんじんと油揚げを切る|5|h|-
S|だしで煮る|15|w|burner

R|potato-salad|ポテトサラダ|side|4|3|0|0
I|じゃがいも|3|個|veg
I|きゅうり|1|本|veg
I|ハム|4|枚|meat
I|マヨネーズ|4|大さじ|season
S|じゃがいもを切る|5|h|-
S|レンジで柔らかくする|8|w|micro
S|きゅうりを塩もみし、ハムを切る|6|h|-
S|じゃがいもをつぶして冷ます|10|w|-
S|全部をあえる|3|h|-

R|piman-okaka|ピーマンのおかか炒め|side|4|3|1|0
I|ピーマン|5|個|veg
I|かつお節|1|袋|dry
I|しょうゆ|1|大さじ|season
I|ごま油|1|大さじ|season
S|ピーマンを細切りにする|5|h|-
S|炒めてかつお節をからめる|5|h|burner

R|kinoko-marine|きのこのマリネ|side|4|4|0|0
I|しめじ|1|パック|veg
I|えのき|1|袋|veg
I|酢|3|大さじ|season
I|オリーブ油|2|大さじ|season
S|きのこをほぐす|4|h|-
S|レンジで加熱する|4|w|micro
S|マリネ液であえる|2|h|-
S|味をなじませる|20|w|-

R|tamagoyaki|だし巻き卵|side|6|2|1|0
I|卵|4|個|egg
I|砂糖|1|大さじ|season
I|だし|50|ml|season
S|卵液を作る|3|h|-
S|焼いて巻く|8|h|burner
S|巻きすで形を整えて冷ます|10|w|-

# ---- 漬け（無料） ----
R|nitamago|味つけ卵|pickle|6|4|0|0
I|卵|6|個|egg
I|しょうゆ|3|大さじ|season
I|みりん|3|大さじ|season
S|湯をわかして卵をゆでる|10|w|burner
S|冷水にとって殻をむく|6|h|-
S|たれに漬ける|60|w|-

R|kyuri-asazuke|きゅうりの浅漬け|pickle|4|3|0|0
I|きゅうり|3|本|veg
I|塩昆布|10|g|dry
S|きゅうりを乱切りにする|3|h|-
S|塩昆布と袋で揉む|2|h|-
S|冷蔵庫でなじませる|30|w|-

# ---- お弁当（Pro） ----
R|soboro|鶏そぼろ|bento|6|4|1|1
I|鶏ひき肉|300|g|meat
I|しょうが|1|かけ|veg
I|しょうゆ|3|大さじ|season
I|砂糖|2|大さじ|season
S|しょうがをすりおろす|2|h|-
S|菜箸4本で混ぜながら炒りつける|10|h|burner

R|iri-tamago|炒り卵|bento|4|2|0|1
I|卵|3|個|egg
I|砂糖|1|大さじ|season
S|卵液を作る|2|h|-
S|弱火で細かく炒る|5|h|burner

R|chikuwa-isobe|ちくわの磯辺焼き|bento|4|3|1|1
I|ちくわ|4|本|meat
I|青のり|1|小さじ|dry
I|小麦粉|3|大さじ|dry
S|ちくわを切り、青のりの衣を作る|4|h|-
S|揚げ焼きにする|8|h|burner

R|ingen-goma|いんげんのごまあえ|bento|4|3|1|1
I|いんげん|1|袋|veg
I|すりごま|2|大さじ|dry
I|しょうゆ|1|大さじ|season
I|砂糖|1|大さじ|season
S|筋を取って切る|4|h|-
S|レンジで加熱する|3|w|micro
S|ごまあえにする|2|h|-

R|tsukune|鶏つくね|bento|8|3|1|1
I|鶏ひき肉|300|g|meat
I|長ねぎ|0.5|本|veg
I|片栗粉|1|大さじ|season
I|しょうゆ|2|大さじ|season
I|みりん|2|大さじ|season
S|ねぎを刻んでタネをこねる|8|h|-
S|小判形にして焼く|12|h|burner
S|たれをからめる|3|h|burner

R|shumai|レンジしゅうまい|bento|12|3|1|1
I|豚ひき肉|250|g|meat
I|玉ねぎ|0.5|個|veg
I|しゅうまいの皮|1|袋|dry
S|タネを作って皮で包む|15|h|-
S|レンジで蒸す|6|w|micro

# ---- 冷凍の素（Pro） ----
R|gyudon|牛丼の具|freeze|4|3|1|1
I|牛こま切れ肉|300|g|meat
I|玉ねぎ|1|個|veg
I|しょうゆ|3|大さじ|season
I|砂糖|2|大さじ|season
I|みりん|2|大さじ|season
S|玉ねぎをくし切りにする|4|h|-
S|煮汁で玉ねぎを煮る|12|w|burner
S|肉を入れてアクを取りながら煮る|6|h|burner

R|keema|キーマカレー|freeze|4|4|1|1
I|合いびき肉|300|g|meat
I|玉ねぎ|1|個|veg
I|にんじん|1|本|veg
I|カレールウ|4|かけ|dry
I|トマト缶|1|缶|dry
S|野菜をみじん切りにする|10|h|-
S|肉と野菜を炒める|8|h|burner
S|トマト缶で煮込む|15|w|burner
S|ルウを溶かして仕上げる|3|h|burner

R|meat-sauce|ミートソース|freeze|6|4|1|1
I|合いびき肉|300|g|meat
I|玉ねぎ|1|個|veg
I|トマト缶|2|缶|dry
I|ケチャップ|3|大さじ|season
S|玉ねぎをみじん切りにする|6|h|-
S|肉と玉ねぎを炒める|8|h|burner
S|トマト缶で煮込む|20|w|burner

R|kinoko-mix|冷凍きのこミックス|freeze|6|30|1|1
I|しめじ|2|パック|veg
I|まいたけ|1|パック|veg
I|えのき|1|袋|veg
S|石づきを取ってほぐす|6|h|-
S|使う分ずつ袋に分ける|3|h|-

R|sake-flake|鮭フレーク|freeze|6|5|1|1
I|生鮭|3|切れ|meat
I|酒|2|大さじ|season
I|白ごま|1|大さじ|dry
S|グリルで鮭を焼く|12|w|oven
S|骨と皮を取ってほぐす|8|h|-
S|酒をふって炒り、水分を飛ばす|6|h|burner

R|negishio|鶏のねぎ塩焼き|freeze|4|3|1|1
I|鶏もも肉|2|枚|meat
I|長ねぎ|1|本|veg
I|ごま油|1|大さじ|season
I|塩|1|小さじ|season
S|鶏肉とねぎを切る|6|h|-
S|下味をなじませる|15|w|-
S|皮目からじっくり焼く|12|h|burner

# ---- 汁の素（Pro） ----
R|tonjiru-no-moto|豚汁の具|soup|6|3|1|1
I|豚バラ薄切り肉|200|g|meat
I|大根|0.25|本|veg
I|にんじん|1|本|veg
I|ごぼう|0.5|本|veg
I|こんにゃく|1|枚|egg
S|具を切る|12|h|-
S|豚肉と具を炒める|4|h|burner
S|水を入れて煮る|15|w|burner

R|minestrone-moto|ミネストローネの素|soup|6|4|1|1
I|玉ねぎ|1|個|veg
I|にんじん|1|本|veg
I|キャベツ|0.25|個|veg
I|ベーコン|4|枚|meat
I|トマト缶|1|缶|dry
S|野菜とベーコンを1cm角に切る|12|h|-
S|炒める|5|h|burner
S|トマト缶で煮込む|20|w|burner

R|miso-dama|みそ玉|soup|10|7|1|1
I|みそ|10|大さじ|season
I|顆粒だし|2|小さじ|season
I|乾燥わかめ|5|g|dry
I|小ねぎ|0.5|束|veg
S|小ねぎを小口切りにする|4|h|-
S|みそと具を混ぜてラップで丸める|10|h|-
S|冷やし固める|30|w|-

# ---- 漬け（Pro） ----
R|tomato-marine|ミニトマトのマリネ|pickle|4|4|0|1
I|ミニトマト|1|パック|veg
I|玉ねぎ|0.25|個|veg
I|酢|2|大さじ|season
I|オリーブ油|2|大さじ|season
S|ミニトマトを湯むきする|8|h|burner
S|マリネ液に漬ける|30|w|-

R|pickles|彩り野菜のピクルス|pickle|6|7|0|1
I|きゅうり|1|本|veg
I|パプリカ|1|個|veg
I|にんじん|0.5|本|veg
I|酢|100|ml|season
I|砂糖|3|大さじ|season
S|野菜をスティックに切る|8|h|-
S|ピクルス液を煮立てる|4|w|burner
S|熱い液に漬けて冷ます|60|w|-

R|hakusai-amazu|白菜の甘酢漬け|pickle|4|5|0|1
I|白菜|0.25|個|veg
I|酢|3|大さじ|season
I|砂糖|2|大さじ|season
I|塩昆布|10|g|dry
S|白菜を切って塩もみする|8|h|-
S|水気を絞って甘酢に漬ける|3|h|-
S|味をなじませる|30|w|-

R|kabu-yuzu|かぶのゆず漬け|pickle|4|4|0|1
I|かぶ|3|個|veg
I|ゆず|0.5|個|veg
I|酢|2|大さじ|season
I|砂糖|1|大さじ|season
S|かぶを薄切りにして塩もみする|8|h|-
S|ゆずの皮と甘酢で漬ける|30|w|-

# ---- 週末のごちそう（Pro） ----
R|kakuni|豚の角煮|main|4|4|1|1
I|豚バラかたまり肉|500|g|meat
I|長ねぎ|1|本|veg
I|しょうが|1|かけ|veg
I|しょうゆ|4|大さじ|season
I|砂糖|3|大さじ|season
S|肉を切って焼き色をつける|8|h|burner
S|ねぎとしょうがで下ゆでする|40|w|burner
S|たれで煮る|30|w|burner

R|chicken-tomato|鶏のトマト煮|main|4|4|1|1
I|鶏もも肉|2|枚|meat
I|玉ねぎ|1|個|veg
I|しめじ|1|パック|veg
I|トマト缶|1|缶|dry
S|鶏肉と野菜を切る|8|h|-
S|鶏肉を皮目から焼く|6|h|burner
S|トマト缶で煮込む|20|w|burner

R|buri-teri|ぶりの照り焼き|main|4|3|1|1
I|ぶり|4|切れ|meat
I|しょうゆ|3|大さじ|season
I|みりん|3|大さじ|season
S|下味に漬ける|15|w|-
S|焼いてたれをからめる|10|h|burner

R|okara|卯の花|side|4|4|1|1
I|おから|150|g|egg
I|にんじん|0.5|本|veg
I|長ねぎ|0.5|本|veg
I|しょうゆ|2|大さじ|season
I|砂糖|2|大さじ|season
S|野菜を刻む|6|h|-
S|おからと炒め煮にする|12|h|burner

R|koya-ni|高野豆腐の含め煮|side|4|4|0|1
I|高野豆腐|4|枚|dry
I|だし|400|ml|season
I|しょうゆ|1|大さじ|season
I|砂糖|2|大さじ|season
S|高野豆腐をぬるま湯で戻す|10|w|-
S|水気を絞って切る|3|h|-
S|だしで煮含める|20|w|burner

R|komatsuna|小松菜と油揚げの煮びたし|side|4|3|1|1
I|小松菜|1|束|veg
I|油揚げ|1|枚|egg
I|だし|200|ml|season
I|しょうゆ|1|大さじ|season
S|小松菜と油揚げを切る|5|h|-
S|だしでさっと煮る|6|w|burner

R|daigaku-imo|大学いも|side|4|3|1|1
I|さつまいも|1|本|veg
I|砂糖|3|大さじ|season
I|しょうゆ|1|大さじ|season
I|黒ごま|1|大さじ|dry
S|さつまいもを切って水にさらす|6|h|-
S|レンジで加熱する|5|w|micro
S|揚げ焼きにして蜜をからめる|10|h|burner
"""
}
