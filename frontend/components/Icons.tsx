type P = { size?: number };
export type IconProps = P;
const base = (size: number) => ({
  width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
  strokeWidth: 2, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, "aria-hidden": true,
});

export const SearchIcon = ({ size = 18 }: P) => (<svg {...base(size)}><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>);
export const BellIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="M6 8a6 6 0 1 1 12 0c0 7 3 9 3 9H3s3-2 3-9" /><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" /></svg>);
export const ShareIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M12 3v13" /><path d="m7 8 5-5 5 5" /><path d="M5 14v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5" /></svg>);
export const MoreIcon = ({ size = 18 }: P) => (<svg {...base(size)}><circle cx="5" cy="12" r="1.2" /><circle cx="12" cy="12" r="1.2" /><circle cx="19" cy="12" r="1.2" /></svg>);
export const PlusIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="M12 5v14M5 12h14" /></svg>);
export const BackIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="M19 12H5" /><path d="m12 19-7-7 7-7" /></svg>);
export const UploadIcon = ({ size = 28 }: P) => (<svg {...base(size)}><path d="M12 16V4" /><path d="m7 9 5-5 5 5" /><path d="M4 20h16" /></svg>);
export const HeartIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M19.5 12.6 12 20l-7.5-7.4A4.8 4.8 0 1 1 12 6.6a4.8 4.8 0 1 1 7.5 6Z" /></svg>);
export const LinkIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7" /><path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7" /></svg>);
export const HomeIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1Z" /></svg>);
export const CheckIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="m5 12 5 5 9-10" /></svg>);
export const LockIcon = ({ size = 16 }: P) => (<svg {...base(size)}><rect x="4" y="11" width="16" height="10" rx="2" /><path d="M8 11V7a4 4 0 0 1 8 0v4" /></svg>);
export const EditIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M12 20h9" /><path d="M16.5 3.5a2.1 2.1 0 1 1 3 3L7 19l-4 1 1-4Z" /></svg>);
export const TrashIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M3 6h18" /><path d="M8 6V4h8v2" /><path d="M19 6l-1 14H6L5 6" /></svg>);
export const CloseIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="M18 6 6 18M6 6l12 12" /></svg>);
export const ExternalIcon = ({ size = 16 }: P) => (<svg {...base(size)}><path d="M14 4h6v6" /><path d="M20 4 10 14" /><path d="M19 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1h5" /></svg>);
export const ChevronDownIcon = ({ size = 16 }: P) => (<svg {...base(size)}><path d="m6 9 6 6 6-6" /></svg>);
export const ChevronLeftIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="m15 18-6-6 6-6" /></svg>);
export const ChevronRightIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="m9 18 6-6-6-6" /></svg>);
export const CartIcon = ({ size = 22 }: P) => (<svg {...base(size)}><circle cx="9" cy="20" r="1.4" /><circle cx="18" cy="20" r="1.4" /><path d="M2.5 3h2.6l2.4 11.6a1.6 1.6 0 0 0 1.6 1.3h8.7a1.6 1.6 0 0 0 1.6-1.2L21 7H6" /></svg>);
export const BagIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M5 8h14l-1 12a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1Z" /><path d="M9 8V6a3 3 0 0 1 6 0v2" /></svg>);
export const EyeIcon = ({ size = 16 }: P) => (<svg {...base(size)}><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z" /><circle cx="12" cy="12" r="3" /></svg>);
export const StarIcon = ({ size = 16, filled = true }: P & { filled?: boolean }) => (
  <svg {...base(size)} fill={filled ? "currentColor" : "none"} strokeWidth={1.6}><path d="m12 3 2.7 5.6 6.1.8-4.5 4.2 1.1 6.1L12 16.8l-5.4 2.9 1.1-6.1-4.5-4.2 6.1-.8Z" /></svg>
);
export const TruckIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M3 6h11v10H3z" /><path d="M14 9h4l3 3v4h-7" /><circle cx="7" cy="18" r="1.8" /><circle cx="17" cy="18" r="1.8" /></svg>);
export const ReturnIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M3 12a9 9 0 1 0 3-6.7" /><path d="M3 4v5h5" /></svg>);
export const ShieldIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M12 3 4 6v6c0 5 3.4 8 8 9 4.6-1 8-4 8-9V6Z" /><path d="m9 12 2 2 4-4" /></svg>);
export const LayersIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="m12 3 9 5-9 5-9-5Z" /><path d="m3 13 9 5 9-5" /></svg>);
export const BoxIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="M21 8 12 3 3 8v8l9 5 9-5Z" /><path d="m3 8 9 5 9-5" /><path d="M12 13v8" /></svg>);
export const CalendarIcon = ({ size = 20 }: P) => (<svg {...base(size)}><rect x="3" y="5" width="18" height="16" rx="2" /><path d="M3 10h18M8 3v4M16 3v4" /></svg>);
export const PhoneIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M5 3h3l2 5-2.5 1.5a11 11 0 0 0 7 7L16 14l5 2v3a2 2 0 0 1-2 2A17 17 0 0 1 3 5a2 2 0 0 1 2-2" /></svg>);
export const ClockIcon = ({ size = 16 }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></svg>);
export const PinMapIcon = ({ size = 16 }: P) => (<svg {...base(size)}><path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11Z" /><circle cx="12" cy="10" r="2.5" /></svg>);
export const TrophyIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="M8 4h8v5a4 4 0 0 1-8 0Z" /><path d="M8 6H4v1a4 4 0 0 0 4 4M16 6h4v1a4 4 0 0 1-4 4" /><path d="M12 13v4M8 21h8M9 21l1-4h4l1 4" /></svg>);
export const CrownIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="m3 8 4.5 4L12 5l4.5 7L21 8l-2 11H5Z" /></svg>);
export const StoreIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="M3 9 5 4h14l2 5" /><path d="M3 9a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0" /><path d="M5 12v8h14v-8" /><path d="M10 20v-5h4v5" /></svg>);
export const UserIcon = ({ size = 22 }: P) => (<svg {...base(size)}><circle cx="12" cy="8" r="4" /><path d="M4 21a8 8 0 0 1 16 0" /></svg>);
export const ChatIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12Z" /></svg>);
export const InfoIcon = ({ size = 16 }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="9" /><path d="M12 11v5M12 8h.01" /></svg>);
export const MinusIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M5 12h14" /></svg>);
export const GridIcon = ({ size = 18 }: P) => (<svg {...base(size)}><rect x="4" y="4" width="7" height="7" rx="1" /><rect x="13" y="4" width="7" height="7" rx="1" /><rect x="4" y="13" width="7" height="7" rx="1" /><rect x="13" y="13" width="7" height="7" rx="1" /></svg>);
export const MasonryIcon = ({ size = 18 }: P) => (<svg {...base(size)}><rect x="4" y="4" width="7" height="10" rx="1" /><rect x="13" y="4" width="7" height="6" rx="1" /><rect x="4" y="16" width="7" height="4" rx="1" /><rect x="13" y="12" width="7" height="8" rx="1" /></svg>);
export const BoardsIcon = ({ size = 18 }: P) => (<svg {...base(size)}><rect x="3" y="4" width="18" height="16" rx="2" /><path d="M12 4v16M12 12h9" /></svg>);
export const SlidersIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0" /><circle cx="16" cy="6" r="2" /><circle cx="10" cy="12" r="2" /><circle cx="18" cy="18" r="2" /></svg>);
export const PackageIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="M21 8 12 3 3 8v8l9 5 9-5Z" /><path d="m3 8 9 5 9-5M7.5 5.5l9 5" /></svg>);
export const ChartIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="M4 20V4M4 20h16" /><path d="m8 15 4-4 3 3 5-6" /></svg>);
export const CashIcon = ({ size = 20 }: P) => (<svg {...base(size)}><rect x="3" y="6" width="18" height="12" rx="2" /><circle cx="12" cy="12" r="2.5" /></svg>);
export const VerifiedIcon = ({ size = 16 }: P) => (
  <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden>
    <path fill="#1D9BF0" d="M12 1.5 14.6 3.6 17.9 3.3 18.9 6.5 21.9 8 21 11.2 22.4 14.2 19.6 16 19.3 19.4 16 19.9 13.9 22.5 12 21.4 10.1 22.5 8 19.9 4.7 19.4 4.4 16 1.6 14.2 3 11.2 2.1 8 5.1 6.5 6.1 3.3 9.4 3.6Z" />
    <path d="m7.8 12.2 2.8 2.8 5.6-5.8" fill="none" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
export const CameraIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="M4 8h3l2-3h6l2 3h3v11H4Z" /><circle cx="12" cy="13" r="3.5" /></svg>);
export const SettingsIcon = ({ size = 18 }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z" /></svg>);
export const LogoutIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" /><path d="m16 17 5-5-5-5M21 12H9" /></svg>);
export const PauseIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M8 5v14M16 5v14" /></svg>);
export const PlayIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="m7 4 13 8-13 8Z" /></svg>);
export const ArrowUpIcon = ({ size = 16 }: P) => (<svg {...base(size)}><path d="M12 19V5M5 12l7-7 7 7" /></svg>);
export const LightbulbIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M9 18h6M10 21h4" /><path d="M12 3a6 6 0 0 0-3.6 10.8c.6.5 1 1.2 1.1 2V16h5v-.2c.1-.8.5-1.5 1.1-2A6 6 0 0 0 12 3Z" /></svg>);
export const DotsIcon = ({ size = 20 }: P) => (<svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden><circle cx="5" cy="12" r="2" /><circle cx="12" cy="12" r="2" /><circle cx="19" cy="12" r="2" /></svg>);
export const BookmarkIcon = ({ size = 22, filled = false }: P & { filled?: boolean }) => (<svg {...base(size)} fill={filled ? "currentColor" : "none"}><path d="M6 3h12v18l-6-4.5L6 21Z" /></svg>);
export const CommentIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="M20.5 11.5a8.5 8.5 0 0 1-12.6 7.4L3 20l1.2-4.6A8.5 8.5 0 1 1 20.5 11.5Z" /></svg>);
export const SendIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="m22 2-11 11" /><path d="M22 2 15 22l-4-9-9-4Z" /></svg>);
export const ReelsIcon = ({ size = 22 }: P) => (<svg {...base(size)}><rect x="3" y="3" width="18" height="18" rx="5" /><path d="M3 8.5h18M8 3l3 5.5M14 3l3 5.5" /><path d="m10.5 12 4 2.5-4 2.5Z" fill="currentColor" stroke="none" /></svg>);
export const VolumeIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M4 9h4l5-4v14l-5-4H4Z" /><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12" /></svg>);
export const MuteIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M4 9h4l5-4v14l-5-4H4Z" /><path d="m17 9 5 6M22 9l-5 6" /></svg>);
export const DownloadIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M12 4v12" /><path d="m7 11 5 5 5-5" /><path d="M4 20h16" /></svg>);
export const CopyIcon = ({ size = 18 }: P) => (<svg {...base(size)}><rect x="8" y="8" width="13" height="13" rx="2" /><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3" /></svg>);
export const FlagIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M5 21V4" /><path d="M5 4h11l-2 4 2 4H5" /></svg>);
export const EyeOffIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M3 3l18 18" /><path d="M10.6 5.1A10 10 0 0 1 12 5c6.4 0 10 7 10 7a17 17 0 0 1-3.2 4.1M6.6 6.6A17 17 0 0 0 2 12s3.6 7 10 7a9.6 9.6 0 0 0 5.4-1.6" /><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2" /></svg>);
export const BanIcon = ({ size = 18 }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="9" /><path d="m5.6 5.6 12.8 12.8" /></svg>);
export const SparkIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8Z" /><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8Z" /></svg>);
export const ScanIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2" /><circle cx="12" cy="12" r="3.2" /></svg>);
export const SquareGridIcon = ({ size = 18 }: P) => (<svg {...base(size)}><rect x="3" y="3" width="18" height="18" rx="2" /><path d="M9 3v18M15 3v18M3 9h18M3 15h18" /></svg>);
export const FeedIcon = ({ size = 18 }: P) => (<svg {...base(size)}><rect x="5" y="3" width="14" height="12" rx="2" /><path d="M5 19h14M5 22h9" /></svg>);
export const HashIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M5 9h15M4 15h15M10 3 8 21M16 3l-2 18" /></svg>);
export const GlobeIcon = ({ size = 18 }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18" /></svg>);
export const InstagramIcon = ({ size = 18 }: P) => (<svg {...base(size)}><rect x="3" y="3" width="18" height="18" rx="5" /><circle cx="12" cy="12" r="4" /><circle cx="17.5" cy="6.5" r="0.8" fill="currentColor" /></svg>);
export const TelegramIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M21 4 3 11l6 2.2M21 4l-3 16-9-6.8M21 4 9 13.2V19l3.2-3" /></svg>);
export const WhatsappIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M3.5 20.5 5 16a8.5 8.5 0 1 1 3.3 3.2Z" /><path d="M9 8.5c0 3.5 3 6.5 6.5 6.5l1-1.6-2-1-1 1a5 5 0 0 1-2.9-2.9l1-1-1-2Z" /></svg>);
export const TiktokIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M14 3v11.5a3.5 3.5 0 1 1-3.5-3.5" /><path d="M14 3c.5 2.8 2.3 4.5 5 4.8" /></svg>);
export const YoutubeIcon = ({ size = 18 }: P) => (<svg {...base(size)}><rect x="2.5" y="5.5" width="19" height="13" rx="4" /><path d="m10 9.5 5 2.5-5 2.5Z" fill="currentColor" /></svg>);
export const ImoIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M20 12a8 8 0 0 1-11.7 7.1L4 20l1-4A8 8 0 1 1 20 12Z" /><path d="M9 10v4M12 10v4M15 10v4" /></svg>);
export const RulerIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="m3 17 14-14 4 4L7 21Z" /><path d="m7 13 2 2M10 10l2 2M13 7l2 2" /></svg>);
