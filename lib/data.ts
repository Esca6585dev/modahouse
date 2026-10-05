export type ArtKind =
  | "mountains"
  | "waves"
  | "circles"
  | "arch"
  | "stripes"
  | "blob"
  | "dress"
  | "plant";

export type Pin = {
  id: string;
  title: string;
  description: string;
  author: string;
  category: string;
  kind: ArtKind;
  palette: number;
  ratio: number;
};

export type Author = { handle: string; name: string; followers: string; color: string };

export const palettes: [string, string, string, string][] = [
  ["#ffcfa8", "#ff8a65", "#ffe082", "#6d4c41"],
  ["#dfe7d5", "#a7c4a0", "#f4e9d8", "#4f6d4a"],
  ["#fde2e4", "#f7a1b5", "#fff1e6", "#9c3d54"],
  ["#cfe8ef", "#5fa8d3", "#f6f1d1", "#1b4965"],
  ["#f2d0b6", "#d9825b", "#f7ece1", "#7a3e2b"],
  ["#e6dcf5", "#a990dd", "#fdf6ff", "#4b3a73"],
  ["#fff1c1", "#f2b134", "#fbfaf4", "#4a4a3a"],
  ["#2b2d42", "#8d99ae", "#edf2f4", "#ef233c"],
  ["#d8f3dc", "#74c69d", "#fefae0", "#2d6a4f"],
  ["#f8e1d7", "#e0a899", "#fffaf5", "#5e3b36"],
];

export const categories = [
  "Moda",
  "Içki bezeg",
  "Tagamlar",
  "Syýahat",
  "Sungat",
  "Ösümlikler",
];

export const authors: Record<string, Author> = {
  "aylar.studio": { handle: "aylar.studio", name: "Aýlar Studio", followers: "12,4 müň", color: "#d6336c" },
  "ic.bezeg": { handle: "ic.bezeg", name: "Içki Bezeg", followers: "8,1 müň", color: "#7a3e2b" },
  "tagam.tm": { handle: "tagam.tm", name: "Tagam TM", followers: "21 müň", color: "#f2b134" },
  gezelenc: { handle: "gezelenc", name: "Gezelenç", followers: "5,7 müň", color: "#1b4965" },
  "renk.lab": { handle: "renk.lab", name: "Reňk Lab", followers: "3,9 müň", color: "#4b3a73" },
  "yasyl.burc": { handle: "yasyl.burc", name: "Ýaşyl Burç", followers: "9,3 müň", color: "#2d6a4f" },
};

const byCategory: Record<string, string> = {
  Moda: "aylar.studio",
  "Içki bezeg": "ic.bezeg",
  Tagamlar: "tagam.tm",
  Syýahat: "gezelenc",
  Sungat: "renk.lab",
  Ösümlikler: "yasyl.burc",
};

const ratios = [1.4, 1.0, 1.6, 1.25, 1.8, 1.15, 1.5, 0.9];

const raw: [string, string, string, ArtKind, number][] = [
  ["Güýz üçin gatlakly geýim", "Salkyn günler üçin ýeňil we ýyly gatlaklary utgaşdyrmagyň ýönekeý usullary.", "Moda", "dress", 4],
  ["Minimalist myhman otagy", "Az zat, köp ýagtylyk: arassa çyzykly we ýumşak reňkli otag.", "Içki bezeg", "arch", 1],
  ["Daglarda gün ýaşmasy", "Agşam ýodasynda iň owadan pursat. Fotoaparatyňyzy unutmaň!", "Syýahat", "mountains", 0],
  ["Ýaşyl öý ösümlikleri", "Az aladany talap edýän we otagy janlandyrýan ösümlikler.", "Ösümlikler", "plant", 8],
  ["Ertirlik üçin miweli tabak", "Täze miweler, gatyk we bal bilen 5 minutda taýýar ertirlik.", "Tagamlar", "circles", 6],
  ["Abstrakt reňk kompozisiýasy", "Ýumşak görnüşler we pastel reňkler bilen diwar sungaty.", "Sungat", "blob", 5],
  ["Zolakly tomus köýnegi", "Tomus günleri üçin ýeňil, howa geçirýän zolakly köýnek.", "Moda", "stripes", 3],
  ["Deňiz kenarynda dynç alyş", "Tolkunlaryň sesi, ýyly gum we uzyn agşamlar.", "Syýahat", "waves", 3],
  ["Boho stilindäki ýatylýan otag", "Tebigy dokumalar, ýyly reňkler we arka görnüşli bezegler.", "Içki bezeg", "arch", 4],
  ["Kaktus kolleksiýasy", "Penjire öňünde ösdürip boljak kiçijik kaktuslar.", "Ösümlikler", "plant", 6],
  ["Agşamlyk köýnek ideýalary", "Toý we baýramçylyklar üçin näzik agşamlyk köýnekler.", "Moda", "dress", 7],
  ["Geometrik diwar suraty", "Tegelekler we çyzyklar bilen döredilen ýönekeý kompozisiýa.", "Sungat", "circles", 0],
  ["Gök çaý we desertler", "Myhmanlar üçin ýeňil desertler we hoşboý gök çaý.", "Tagamlar", "circles", 8],
  ["Ýaýla ýodasy", "Dag ýodalary boýunça bir günlük gezelenç meýilnamasy.", "Syýahat", "mountains", 1],
  ["Retro plakat dizaýny", "Ýetmişinji ýyllaryň ruhunda zolakly plakat.", "Sungat", "stripes", 6],
  ["Aşhana üçin tebigy reňkler", "Toprak reňkleri aşhanany has ýyly we rahat edýär.", "Içki bezeg", "blob", 4],
  ["Ýüpek şarf baglamagyň usullary", "Bir şarf, on dürli görnüş. Gündelik geýim üçin ideýalar.", "Moda", "waves", 2],
  ["Balkondaky kiçijik bag", "Kiçi meýdanda gök önüm we gül ösdürmegiň tilsimleri.", "Ösümlikler", "plant", 1],
  ["Okean tolkunlary", "Mawy reňkiň ähli öwüşginleri bir suratda.", "Syýahat", "waves", 3],
  ["Pastel reňkli köýnekler", "Ýaz paslyna laýyk ýumşak we açyk reňkler.", "Moda", "dress", 2],
  ["Gijeki şäher", "Şäheriň ýagtylyklary we ümsüm köçeleri.", "Syýahat", "mountains", 7],
  ["Akwarel tehnikasy", "Başlangyçlar üçin akwarel bilen işlemegiň esaslary.", "Sungat", "blob", 2],
  ["Öýde bişirilen çörek", "Tamdyr tagamly ýumşak çörek, ädimme-ädim resept.", "Tagamlar", "circles", 4],
  ["Arka görnüşli aýna", "Dälizi giňeldýän we ýagtylandyrýan bezeg aýnasy.", "Içki bezeg", "arch", 9],
  ["Klassyk palto", "Her möwsümde moda bolup galýan klassyk palto.", "Moda", "dress", 9],
  ["Monstera aladasy", "Monstera ösümligini suwarmak we ýagtylyk boýunça maslahatlar.", "Ösümlikler", "plant", 8],
  ["Çöl gün dogşy", "Gum depeleriniň üstünde täze günüň başlanyşy.", "Syýahat", "mountains", 6],
  ["Minimal şaý-sepler", "Ýönekeý, ýöne täsirli altyn şaý-sepler.", "Moda", "circles", 9],
  ["Reňkli smuzi", "Üç gatlakly, witaminlere baý miweli smuzi.", "Tagamlar", "stripes", 2],
  ["Keramika wazalar", "El bilen ýasalan keramika wazalar bilen stol bezegi.", "Sungat", "arch", 5],
];

export const pins: Pin[] = raw.map(([title, description, category, kind, palette], i) => ({
  id: String(i + 1),
  title,
  description,
  category,
  kind,
  palette,
  author: byCategory[category],
  ratio: ratios[i % ratios.length],
}));

export function getPin(id: string): Pin | undefined {
  return pins.find((p) => p.id === id);
}

export const currentUser = authors["aylar.studio"];

export const boards = [
  { name: "Güýz geýimleri", pinIds: ["1", "11", "25", "20", "7"] },
  { name: "Arzuw öýi", pinIds: ["2", "9", "24", "16"] },
  { name: "Syýahat sanawy", pinIds: ["3", "8", "14", "19", "21", "27"] },
  { name: "Reseptler", pinIds: ["5", "13", "23", "29"] },
  { name: "Ilham", pinIds: ["6", "12", "15", "22", "30"] },
  { name: "Ösümliklerim", pinIds: ["4", "10", "18", "26"] },
];

export const sampleComments = [
  { author: "gezelenc", text: "Örän owadan! Reňkleri haýsy programmada saýladyňyz?" },
  { author: "renk.lab", text: "Men hem şuňa meňzeş zat edip görjek. Ideýa üçin sag boluň 🙌" },
];
