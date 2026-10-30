// Landing pages for search engines, one per topic and language:
// /fasonlar/<slug> (Turkmen), /ru/<slug> (Russian), /en/<slug> (English).
// Each lists real posts found with the backend's multilingual search.

export type Lang = "tk" | "ru" | "en";
export const LANGS: Lang[] = ["tk", "ru", "en"];

type Text = { title: string; h1: string; intro: string; keywords: string[] };

export type Topic = {
  slug: string;
  /** Backend filter: a post category and/or a search query. */
  category?: string;
  q?: string;
  text: Record<Lang, Text>;
};

export const TOPICS: Topic[] = [
  {
    slug: "fasonlar",
    text: {
      tk: { title: "Fasonlar 2026: köýnek fasonlary, ştapel we milli fasonlar", h1: "Fasonlar", intro: "Täze köýnek fasonlary, ştapel fasonlar, milli köýnekler, gelin we toý köýnekleri, ýaka fasonlary we el keşdeleri. Halan fasonyňyzy saklaň, tikinçä ugradyň ýa-da ussany ModaHouse-da tapyň.", keywords: ["fasonlar", "fason", "köýnek fasonlary", "koynek fasonlar", "täze fasonlar 2026", "türkmen fasonlar"] },
      ru: { title: "Фасоны платьев 2026: туркменские, штапельные и национальные", h1: "Фасоны платьев", intro: "Новые фасоны платьев: штапельные, национальные туркменские, свадебные и вечерние платья, воротники и ручная вышивка. Сохраняйте понравившиеся фасоны, отправляйте портнихе или найдите мастера на ModaHouse.", keywords: ["фасоны платьев", "фасоны", "туркменские платья", "модные платья 2026", "платья фасоны фото"] },
      en: { title: "Dress styles 2026: Turkmen, national and everyday designs", h1: "Dress styles", intro: "New dress designs from Turkmenistan: everyday and staple dresses, national Turkmen dresses, wedding and evening gowns, necklines and hand embroidery. Save the styles you like, send them to a tailor or find a master on ModaHouse.", keywords: ["dress styles", "dress designs", "turkmen dress", "turkmen fashion", "dress ideas 2026"] },
    },
  },
  {
    slug: "koynekler", q: "koynek",
    text: {
      tk: { title: "Köýnekler: gyzlar üçin köýnek fasonlary", h1: "Köýnekler", intro: "Gyzlar we zenanlar üçin köýnekler: uzyn, gysga, keşdeli, atlas we ştapel köýnekler. Suratlary görüň, saklaň we tikdiriň.", keywords: ["köýnekler", "koynekler", "köýnek", "gyz köýnekleri", "köýnek suratlary"] },
      ru: { title: "Платья для девушек: фасоны и фото", h1: "Платья", intro: "Платья для девушек и женщин: длинные и короткие, с вышивкой, атласные и штапельные. Смотрите фото, сохраняйте и шейте на заказ.", keywords: ["платья", "платья для девушек", "женские платья", "платья фото", "платья на заказ"] },
      en: { title: "Dresses for women and girls: styles and photos", h1: "Dresses", intro: "Dresses for women and girls: long and short, embroidered, satin and staple dresses. Browse photos, save them and have them tailored.", keywords: ["dresses", "women dresses", "dress for girls", "dress photos", "custom dress"] },
    },
  },
  {
    slug: "gelin-koynekleri", category: "gelin",
    text: {
      tk: { title: "Gelin köýnekleri we gelin lybaslary", h1: "Gelin köýnekleri", intro: "Gelin köýnekleri, ak nika köýnekleri, milli gelin lybaslary we gelin üçin şaý-sepler. Satyn alyň, kärendesine alyň ýa-da tikdiriň.", keywords: ["gelin köýnekleri", "gelin koynek", "gelin lybaslary", "nika köýnegi", "türkmen gelin"] },
      ru: { title: "Свадебные платья: туркменские и современные", h1: "Свадебные платья", intro: "Свадебные платья, туркменские национальные наряды невесты и украшения. Купить, взять напрокат или сшить на заказ.", keywords: ["свадебные платья", "платье невесты", "туркменская свадьба", "свадебное платье напрокат"] },
      en: { title: "Wedding dresses: Turkmen and modern bridal gowns", h1: "Wedding dresses", intro: "Wedding dresses, Turkmen national bridal outfits and jewelry. Buy, rent or have one made to order.", keywords: ["wedding dresses", "bridal gowns", "turkmen wedding", "bride dress"] },
    },
  },
  {
    slug: "toy-koynekleri", category: "toy",
    text: {
      tk: { title: "Toý köýnekleri we agşam köýnekleri", h1: "Toý köýnekleri", intro: "Toý, baýramçylyk we agşam üçin köýnekler: atlas, barhat, keşdeli we ýalpyldawuk fasonlar.", keywords: ["toý köýnekleri", "toy koynek", "agşam köýnegi", "baýramçylyk köýnegi"] },
      ru: { title: "Вечерние и праздничные платья на той", h1: "Вечерние платья", intro: "Платья на той, праздник и вечер: атласные, бархатные, с вышивкой и блестящие фасоны.", keywords: ["вечерние платья", "платье на той", "праздничные платья", "платья на свадьбу гостям"] },
      en: { title: "Evening and party dresses", h1: "Evening dresses", intro: "Dresses for weddings, celebrations and evenings: satin, velvet, embroidered and sparkling styles.", keywords: ["evening dresses", "party dresses", "wedding guest dress", "gowns"] },
    },
  },
  {
    slug: "milli-koynekler", category: "milli",
    text: {
      tk: { title: "Milli köýnekler: türkmen milli lybaslary", h1: "Milli köýnekler", intro: "Türkmen milli köýnekleri, keteni, keşdeli ýakalar we milli nagyşlar. Häzirki zaman we nusgawy fasonlar.", keywords: ["milli köýnek", "milli koynek", "türkmen milli lybasy", "keteni köýnek"] },
      ru: { title: "Туркменские национальные платья", h1: "Национальные платья", intro: "Туркменские национальные платья, ткань кетени, вышитые воротники и орнаменты. Современные и классические фасоны.", keywords: ["туркменское национальное платье", "национальные платья", "кетени", "туркменский костюм"] },
      en: { title: "Turkmen national dresses", h1: "Turkmen national dresses", intro: "Turkmen national dresses, keteni silk, embroidered collars and traditional patterns, in modern and classic styles.", keywords: ["turkmen national dress", "traditional turkmen clothing", "keteni", "central asian dress"] },
    },
  },
  {
    slug: "stapel", q: "stapel",
    text: {
      tk: { title: "Ştapel fasonlar 2026", h1: "Ştapel fasonlar", intro: "Ştapel köýnekler: ýeňil, gündelik we tomus üçin fasonlar. Täze ştapel fasonlaryny görüň we tikdiriň.", keywords: ["ştapel fasonlar", "stapel fasonlar", "ştapel köýnek", "stapel koynek 2026"] },
      ru: { title: "Штапельные платья: фасоны 2026", h1: "Штапельные платья", intro: "Платья из штапеля: лёгкие, повседневные и летние фасоны.", keywords: ["штапельные платья", "платье из штапеля", "штапель фасоны"] },
      en: { title: "Staple (rayon) dresses 2026", h1: "Staple dresses", intro: "Light rayon (staple) dresses: everyday and summer styles.", keywords: ["staple dress", "rayon dress", "summer dress styles"] },
    },
  },
  {
    slug: "kurte", q: "kurte",
    text: {
      tk: { title: "Kürte fasonlary", h1: "Kürte", intro: "Kürte fasonlary we kürte tikinçileri: gündelik we baýramçylyk üçin.", keywords: ["kürte", "kurte", "kürte fasonlary", "kurte fason"] },
      ru: { title: "Курте: фасоны и пошив", h1: "Курте", intro: "Фасоны курте и мастера по пошиву курте.", keywords: ["курте", "курте фасоны", "туркменское курте"] },
      en: { title: "Kurte styles", h1: "Kurte", intro: "Kurte styles and the tailors who make them.", keywords: ["kurte", "kurta", "turkmen kurte"] },
    },
  },
  {
    slug: "bukja", q: "bukja",
    text: {
      tk: { title: "Bukja: toý bukjalary we sowgatlar", h1: "Bukja", intro: "Toý we gelin üçin bukjalar, sowgatlyk bukjalar we olary bezemegiň ideýalary.", keywords: ["bukja", "toý bukja", "gelin bukja", "bukja bezegi"] },
      ru: { title: "Букча: свадебные свёртки и подарки", h1: "Букча", intro: "Букча на свадьбу и для невесты: подарочные свёртки и идеи оформления.", keywords: ["букча", "букджа", "свадебные подарки", "туркменская свадьба подарки"] },
      en: { title: "Bukja: wedding gift bundles", h1: "Bukja", intro: "Bukja wedding and bridal gift bundles and ideas for decorating them.", keywords: ["bukja", "wedding gift bundle", "turkmen wedding gifts"] },
    },
  },
  {
    slug: "yaka-fasonlary", category: "yaka",
    text: {
      tk: { title: "Ýaka fasonlary we keşdeli ýakalar", h1: "Ýaka fasonlary", intro: "Köýnek ýakalarynyň fasonlary: keşdeli, tegelek, dik we milli ýakalar.", keywords: ["ýaka fasonlary", "yaka fason", "keşdeli ýaka", "köýnek ýakasy"] },
      ru: { title: "Фасоны воротников и горловин платья", h1: "Фасоны воротников", intro: "Воротники и горловины платьев: с вышивкой, круглые, стойка и национальные.", keywords: ["фасоны воротников", "воротник платья", "горловина платья", "вышитый воротник"] },
      en: { title: "Collar and neckline designs", h1: "Collar designs", intro: "Dress collars and necklines: embroidered, round, stand-up and national styles.", keywords: ["collar designs", "neckline designs", "embroidered collar"] },
    },
  },
  {
    slug: "el-keshdeleri", category: "keshde",
    text: {
      tk: { title: "El keşdeleri we türkmen keşdesi", h1: "El keşdeleri", intro: "Türkmen el keşdesi: ýakalar, ýeňler, nagyşlar we keşdeli köýnekler. El keşdeçileri tapyň.", keywords: ["el keşdeleri", "el kesde", "türkmen keşdesi", "keşdeli köýnek"] },
      ru: { title: "Туркменская ручная вышивка", h1: "Ручная вышивка", intro: "Туркменская ручная вышивка: воротники, рукава, орнаменты и платья с вышивкой. Найдите мастера вышивки.", keywords: ["туркменская вышивка", "ручная вышивка", "вышивка на платье", "вышитые платья"] },
      en: { title: "Turkmen hand embroidery", h1: "Hand embroidery", intro: "Turkmen hand embroidery: collars, sleeves, patterns and embroidered dresses. Find an embroidery master.", keywords: ["turkmen embroidery", "hand embroidery", "embroidered dress"] },
    },
  },
  {
    slug: "gundelik", category: "gundelik",
    text: {
      tk: { title: "Gyzlar üçin gündelik köýnekler we obrazlar", h1: "Gündelik moda", intro: "Gyzlar üçin gündelik köýnekler, ýeňil obrazlar we moda ideýalary.", keywords: ["gündelik köýnek", "gyz köýnekleri", "gyzlar üçin moda", "gundelik moda"] },
      ru: { title: "Повседневные платья и образы для девушек", h1: "Повседневная мода", intro: "Повседневные платья для девушек, лёгкие образы и идеи.", keywords: ["повседневные платья", "мода для девушек", "образы на каждый день"] },
      en: { title: "Casual dresses and outfits for girls", h1: "Casual fashion", intro: "Everyday dresses for girls, easy outfits and fashion ideas.", keywords: ["casual dresses", "fashion for girls", "everyday outfits"] },
    },
  },
  {
    slug: "dyrnak", category: "dyrnak",
    text: {
      tk: { title: "Dyrnak dizaýny we dyrnakçylar", h1: "Dyrnak dizaýny", intro: "Dyrnak dizaýny ideýalary, toý we gündelik manikýur. Ýakynyňyzdaky dyrnakçyny tapyň.", keywords: ["dyrnak", "dyrnak dizaýny", "dyrnakçy", "manikýur"] },
      ru: { title: "Дизайн ногтей и маникюр: идеи и мастера", h1: "Дизайн ногтей", intro: "Идеи дизайна ногтей, свадебный и повседневный маникюр. Найдите мастера маникюра.", keywords: ["дизайн ногтей", "маникюр", "мастер маникюра", "свадебный маникюр"] },
      en: { title: "Nail art ideas and nail artists", h1: "Nail art", intro: "Nail art ideas, bridal and everyday manicure. Find a nail artist near you.", keywords: ["nail art", "manicure", "nail designs", "nail artist"] },
    },
  },
  {
    slug: "sac", category: "sac",
    text: {
      tk: { title: "Saç düzümleri: örüm, topbak, gelin saçy", h1: "Saç düzümleri", intro: "Saç düzümleri: örümler, topbaklar, tolkunlar we gelin saç düzümleri.", keywords: ["saç düzümleri", "sac duzumi", "örüm", "gelin saçy"] },
      ru: { title: "Причёски: косы, пучки, свадебные причёски", h1: "Причёски", intro: "Причёски: косы, пучки, локоны и свадебные причёски.", keywords: ["причёски", "свадебные причёски", "косы", "причёски для девушек"] },
      en: { title: "Hairstyles: braids, buns and bridal hair", h1: "Hairstyles", intro: "Hairstyles: braids, buns, waves and bridal hair.", keywords: ["hairstyles", "bridal hair", "braids", "hairstyles for girls"] },
    },
  },
  {
    slug: "makiyaj", category: "makiyaj",
    text: {
      tk: { title: "Makiýaž: toý we gündelik makiýaž", h1: "Makiýaž", intro: "Toý, gelin we gündelik makiýaž ideýalary we makiýažçylar.", keywords: ["makiýaž", "makiyaj", "gelin makiýažy", "makiýažçy"] },
      ru: { title: "Макияж: свадебный и повседневный", h1: "Макияж", intro: "Идеи свадебного, вечернего и повседневного макияжа и визажисты.", keywords: ["макияж", "свадебный макияж", "визажист", "вечерний макияж"] },
      en: { title: "Makeup: bridal and everyday looks", h1: "Makeup", intro: "Bridal, evening and everyday makeup ideas and makeup artists.", keywords: ["makeup", "bridal makeup", "makeup artist", "evening makeup"] },
    },
  },
  {
    slug: "shay-sepler", category: "shay",
    text: {
      tk: { title: "Şaý-sepler: türkmen kümüş bezegleri", h1: "Şaý-sepler", intro: "Türkmen şaý-sepleri: kümüş bezegler, gelin şaýlary we aksessuarlar.", keywords: ["şaý-sepler", "say sepler", "türkmen şaýlary", "kümüş"] },
      ru: { title: "Туркменские украшения из серебра", h1: "Украшения", intro: "Туркменские украшения: серебро, украшения невесты и аксессуары.", keywords: ["туркменские украшения", "серебряные украшения", "украшения невесты"] },
      en: { title: "Turkmen silver jewelry", h1: "Jewelry", intro: "Turkmen jewelry: silver pieces, bridal jewelry and accessories.", keywords: ["turkmen jewelry", "silver jewelry", "bridal jewelry"] },
    },
  },
  {
    slug: "fata", q: "fata",
    text: {
      tk: { title: "Fata we ýaglyklar", h1: "Fata", intro: "Gelin fatalary, ýaglyklar we olary daňmagyň ýollary. Fata satyjylary tapyň.", keywords: ["fata", "gelin fatasy", "ýaglyk", "fata satyjy"] },
      ru: { title: "Фата и платки", h1: "Фата", intro: "Свадебная фата, платки и способы их повязать. Найдите продавцов фаты.", keywords: ["фата", "свадебная фата", "платки", "купить фату"] },
      en: { title: "Bridal veils and headscarves", h1: "Veils", intro: "Bridal veils, headscarves and ways to tie them. Find veil sellers.", keywords: ["bridal veil", "headscarf", "veil"] },
    },
  },
];

export const topic = (slug: string) => TOPICS.find((t) => t.slug === slug);

export function topicPath(lang: Lang, slug: string): string {
  if (lang === "tk") return slug === "fasonlar" ? "/fasonlar" : `/fasonlar/${slug}`;
  return slug === "fasonlar" ? `/${lang}` : `/${lang}/${slug}`;
}

export const UI: Record<Lang, { all: string; more: string; prev: string; open: string; empty: string; topics: string; by: string }> = {
  tk: { all: "Hemmesi", more: "Indiki", prev: "Öňki", open: "ModaHouse-da aç", empty: "Entek post ýok. Ilkinji bolup goşuň!", topics: "Temalar", by: "awtor" },
  ru: { all: "Все", more: "Дальше", prev: "Назад", open: "Открыть в ModaHouse", empty: "Пока нет публикаций. Добавьте первую!", topics: "Темы", by: "автор" },
  en: { all: "All", more: "Next", prev: "Previous", open: "Open in ModaHouse", empty: "No posts yet. Add the first one!", topics: "Topics", by: "by" },
};
