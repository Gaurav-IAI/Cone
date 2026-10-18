import { useEffect, useState, type FormEvent } from "react";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  sendPasswordResetEmail,
  getMultiFactorResolver,
  PhoneAuthProvider,
  PhoneMultiFactorGenerator,
  RecaptchaVerifier,
  type MultiFactorResolver,
  type MultiFactorError,
  type AuthError,
} from "firebase/auth";
import {
  LayoutDashboard,
  Users,
  ShieldCheck,
  CalendarDays,
  BookOpen,
  Utensils,
  Image,
  FileSpreadsheet,
  Mail,
  Activity,
  Settings,
  ScrollText,
  ChevronRight,
  Search,
  Plus,
  ArrowUpRight,
  LogOut,
  Menu,
  X,
  LoaderCircle,
  Download,
  Upload,
  CheckCircle2,
  AlertCircle,
  GraduationCap,
  Layers,
  Ticket,
} from "lucide-react";
import { auth, configured, request } from "./firebase";
import EmailCenter from "./EmailCenter";
import PassCenter from "./PassCenter";
import ConferenceEditor from "./ConferenceEditor";
import InviteUser from "./InviteUser";
import ImportCenter from "./ImportCenter";
import MfaEnrollment from "./MfaEnrollment";
import {
  can,
  conferenceRoles,
  accessRoles,
  type Actor,
  type Module,
} from "../shared/schema";

type Row = Record<string, unknown> & { id: string };
type Field = {
  key: string;
  label: string;
  type?: string;
  options?: readonly string[];
  required?: boolean;
};
const identityFields: Field[] = [
  { key: "fullName", label: "Full name", required: true },
  { key: "email", label: "Email address", type: "email", required: true },
  { key: "mobile", label: "Mobile number", type: "tel", required: true },
];
const fields: Record<Module, Field[]> = {
  venues: [
    { key: "name", label: "Venue name", required: true },
    { key: "location", label: "Location", required: true },
    { key: "capacity", label: "Capacity", type: "number", required: true },
  ],
  staff: [
    {
      key: "staffEmail",
      label: "Organizer / volunteer email",
      type: "email",
      required: true,
    },
    { key: "duty", label: "Duty", required: true },
    { key: "day", label: "Date", type: "date", required: true },
    { key: "start", label: "Start", type: "time", required: true },
    { key: "end", label: "End", type: "time", required: true },
    {
      key: "vipEmail",
      label: "VIP liaison for (optional email)",
      type: "email",
    },
  ],
  fees: [
    {
      key: "participantEmail",
      label: "Participant email",
      type: "email",
      required: true,
    },
    {
      key: "amount",
      label: "Amount (whole INR)",
      type: "number",
      required: true,
    },
    { key: "currency", label: "Currency", options: ["INR"] },
    {
      key: "status",
      label: "Fee status",
      options: ["pending", "received", "waived", "refunded"],
    },
    { key: "reference", label: "Payment / administrative reference" },
  ],
  participants: [
    ...identityFields,
    { key: "affiliation", label: "Affiliation", required: true },
    { key: "role", label: "Conference role", options: conferenceRoles },
    {
      key: "registrationStatus",
      label: "Registration status",
      options: ["pending", "confirmed", "cancelled", "suspended"],
    },
    { key: "discipline", label: "Discipline" },
    {
      key: "category",
      label: "Category",
      options: ["", "I", "II", "III", "IV"],
    },
    {
      key: "presentationType",
      label: "Presentation type",
      options: ["", "O", "P"],
    },
    { key: "registrationFee", label: "Registration fee (INR)", type: "number" },
    { key: "accommodation", label: "Accommodation", options: ["No", "Yes"] },
    { key: "softCopy", label: "Soft copy", options: ["No", "Yes"] },
    { key: "earlierAwardee", label: "Earlier awardee", options: ["No", "Yes"] },
  ],
  users: [
    ...identityFields,
    { key: "accessRole", label: "Dashboard access", options: accessRoles },
    { key: "conferenceId", label: "Conference", options: ["main"] },
    { key: "status", label: "Account status", options: ["active", "disabled"] },
  ],
  sessions: [
    { key: "title", label: "Session title", required: true },
    { key: "day", label: "Date", type: "date", required: true },
    { key: "start", label: "Start", type: "time", required: true },
    { key: "end", label: "End", type: "time", required: true },
    { key: "venue", label: "Venue", required: true },
    {
      key: "kind",
      label: "Kind",
      options: ["general", "session", "presentation", "personal"],
    },
  ],
  disciplines: [
    { key: "name", label: "Discipline name", required: true },
    { key: "code", label: "Code", required: true },
    { key: "oral", label: "Source oral total", type: "number" },
    { key: "poster", label: "Source poster total", type: "number" },
  ],
  submissions: [
    { key: "title", label: "Paper title", required: true },
    { key: "submissionId", label: "Submission ID", required: true },
    {
      key: "presenterEmail",
      label: "Presenter email",
      type: "email",
      required: true,
    },
    { key: "abstractText", label: "Abstract", type: "textarea" },
    {
      key: "authors",
      label: "Authors (one per line)",
      type: "textarea",
      required: true,
    },
    { key: "discipline", label: "Discipline", required: true },
    { key: "category", label: "Category", options: ["I", "II", "III", "IV"] },
    { key: "presentationType", label: "Presentation", options: ["O", "P"] },
  ],
  meals: [
    { key: "day", label: "Date", type: "date", required: true },
    { key: "meal", label: "Meal", options: ["breakfast", "lunch", "dinner"] },
    {
      key: "window",
      label: "Display window (e.g. 08:00–09:30)",
      required: true,
    },
    { key: "opensAt", label: "Opens at (ISO with timezone)", required: true },
    { key: "closesAt", label: "Closes at (ISO with timezone)", required: true },
  ],
};
const navigation = [
  {
    label: "Overview",
    key: "overview",
    icon: LayoutDashboard,
    permission: "reports",
  },
  {
    label: "Participants",
    key: "participants",
    icon: Users,
    permission: "participants",
  },
  {
    label: "Users & access",
    key: "users",
    icon: ShieldCheck,
    permission: "users",
  },
  {
    label: "Programme",
    key: "sessions",
    icon: CalendarDays,
    permission: "sessions",
  },
  {
    label: "Disciplines",
    key: "disciplines",
    icon: Layers,
    permission: "disciplines",
  },
  {
    label: "Papers & authors",
    key: "submissions",
    icon: BookOpen,
    permission: "submissions",
  },
  {
    label: "Meals & coupons",
    key: "meals",
    icon: Utensils,
    permission: "meals",
  },
  {
    label: "Passes & entry",
    key: "passes",
    icon: Ticket,
    permission: "passes",
  },
  {
    label: "Meal desk",
    key: "redemptions",
    icon: Ticket,
    permission: "redemptions",
  },
  { label: "Venues", key: "venues", icon: Layers, permission: "venues" },
  {
    label: "Staff & VIP hosts",
    key: "staff",
    icon: Users,
    permission: "staff",
  },
  { label: "Fee records", key: "fees", icon: BookOpen, permission: "fees" },
  { label: "Media library", key: "media", icon: Image, permission: "media" },
  {
    label: "Excel imports",
    key: "imports",
    icon: FileSpreadsheet,
    permission: "imports",
  },
  { label: "Email / SMTP", key: "email", icon: Mail, permission: "email" },
  {
    label: "Code & system health",
    key: "analysis",
    icon: Activity,
    permission: "analysis",
  },
  {
    label: "Conference",
    key: "conference",
    icon: GraduationCap,
    permission: "conference",
  },
  { label: "Audit log", key: "audit", icon: ScrollText, permission: "audit" },
  {
    label: "Application settings",
    key: "settings",
    icon: Settings,
    permission: "settings",
  },
];
function label(value: unknown): string {
  if (value == null) return "—";
  if (typeof value === "object") return JSON.stringify(value);
  return String(value).replaceAll("_", " ");
}
function Message({ error }: { error: string }) {
  return error ? (
    <div className="message" role="alert">
      <AlertCircle size={18} />
      {error}
    </div>
  ) : null;
}
function Loading() {
  return (
    <div className="loading">
      <LoaderCircle className="spin" size={22} /> Loading conference data…
    </div>
  );
}
function Empty({
  title = "No records yet",
  description = "Add your first record to get started.",
}) {
  return (
    <div className="empty">
      <Layers size={30} />
      <h3>{title}</h3>
      <p>{description}</p>
    </div>
  );
}
export default function App() {
  const [actor, setActor] = useState<Actor | null>(null),
    [checking, setChecking] = useState(true),
    [error, setError] = useState(""),
    [page, setPage] = useState("overview"),
    [mobile, setMobile] = useState(false),
    [revision, setRevision] = useState(0);
  useEffect(() => {
    if (!auth) {
      setChecking(false);
      return;
    }
    return onAuthStateChanged(auth, async (user) => {
      setChecking(true);
      setError("");
      try {
        if (user) {
          const me = await request<Actor>("/me");
          setActor(me);
          setPage(
            navigation.find((n) => can(me, n.permission))?.key || "profile",
          );
        } else setActor(null);
      } catch (e) {
        setActor(null);
        setError((e as Error).message);
      } finally {
        setChecking(false);
      }
    });
  }, [revision]);
  if (checking)
    return (
      <div className="login-screen">
        <Loading />
      </div>
    );
  if (!actor)
    return <Login error={error} retry={() => setRevision((r) => r + 1)} />;
  const current = navigation.find((n) => n.key === page);
  return (
    <div className="shell">
      <aside className={mobile ? "sidebar open" : "sidebar"}>
        <a
          className="brand"
          href="#overview"
          onClick={() => setPage("overview")}
        >
          <span className="brand-icon">C</span>
          <span>
            CONE<small>CONFERENCE OPERATIONS</small>
          </span>
        </a>
        <div className="workspace">
          <span className="event-mark">21</span>
          <div>
            <strong>USSTC 2026–27</strong>
            <small>Conference workspace</small>
          </div>
          <ChevronRight size={16} />
        </div>
        <p className="nav-caption">WORKSPACE</p>
        <nav>
          {navigation
            .filter((n) => can(actor, n.permission))
            .map((n) => (
              <button
                key={n.key}
                className={page === n.key ? "nav-item active" : "nav-item"}
                onClick={() => {
                  setPage(n.key);
                  setMobile(false);
                }}
              >
                <n.icon size={18} />
                {n.label}
                {page === n.key && <span className="nav-dot" />}
              </button>
            ))}
        </nav>
        <div className="sidebar-footer">
          <div className="secure-label">
            <ShieldCheck size={16} />
            Permission-controlled workspace
          </div>
          <button
            className="account"
            onClick={() => void signOut(auth!)}
            title="Sign out"
          >
            <span className="avatar">{actor.fullName.slice(0, 1)}</span>
            <span>
              <strong>{actor.fullName}</strong>
              <small>{label(actor.role)}</small>
            </span>
            <LogOut size={16} />
          </button>
        </div>
      </aside>
      <div className="main">
        <header className="topbar">
          <button
            className="icon-button mobile-toggle"
            onClick={() => setMobile(!mobile)}
            aria-label="Toggle navigation"
          >
            <Menu size={22} />
          </button>
          <span className="breadcrumb">
            Workspace <ChevronRight size={14} />{" "}
            <strong>{current?.label || "My account"}</strong>
          </span>
          <div className="topbar-right">
            <span className="live-dot" /> Firebase connected
            <span className="top-avatar">{actor.fullName.slice(0, 1)}</span>
          </div>
        </header>
        <main className="content">
          <div className="page-heading">
            <div>
              <p className="eyebrow">CONE ADMINISTRATION</p>
              <h1>{current?.label || "My account"}</h1>
              <p className="subtitle">
                {page === "overview"
                  ? "Your conference, at a glance. Keep every detail moving."
                  : "Manage your conference with confidence."}
              </p>
            </div>
            <span className="date-chip">
              {new Date().toLocaleDateString("en-IN", {
                day: "numeric",
                month: "short",
                year: "numeric",
                timeZone: "Asia/Kolkata",
              })}
            </span>
          </div>
          <div key={page}>
            {page === "overview" ? (
              <Overview navigate={setPage} />
            ) : page in fields ? (
              <Records module={page as Module} />
            ) : page === "imports" ? (
              <ImportCenter />
            ) : page === "media" ? (
              <Media />
            ) : page === "email" ? (
              <EmailCenter isSuperAdmin={actor.role === "superadmin"}>
                <Email />
              </EmailCenter>
            ) : page === "conference" ? (
              <ConferenceEditor />
            ) : page === "passes" ? (
              <PassCenter />
            ) : page === "settings" ? (
              <SettingsPage />
            ) : page === "analysis" ? (
              <Analysis />
            ) : page === "redemptions" ? (
              <Redemptions />
            ) : page === "audit" ? (
              <LogTable endpoint="audit" />
            ) : (
              <div className="panel">
                <h2>{actor.fullName}</h2>
                <p>{actor.email}</p>
                <p>Participant records are available in the CONE mobile app.</p>
              </div>
            )}
          </div>
          <footer className="page-footer">
            CONE · Conference Operations & Networking Environment
            <span>USSTC · Administrative workspace</span>
          </footer>
        </main>
      </div>
    </div>
  );
}
function Login({
  error: externalError,
  retry,
}: {
  error: string;
  retry: () => void;
}) {
  const [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [note, setNote] = useState(""),
    [resolver, setResolver] = useState<MultiFactorResolver | null>(null),
    [verification, setVerification] = useState("");
  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!auth) return;
    setBusy(true);
    setError("");
    const values = new FormData(e.currentTarget);
    try {
      if (resolver) {
        const credential = PhoneAuthProvider.credential(
          verification,
          String(values.get("code")),
        );
        await resolver.resolveSignIn(
          PhoneMultiFactorGenerator.assertion(credential),
        );
        retry();
      } else {
        await signInWithEmailAndPassword(
          auth,
          String(values.get("email")),
          String(values.get("password")),
        );
        retry();
      }
    } catch (err) {
      if ((err as AuthError).code === "auth/multi-factor-auth-required") {
        try {
          const next = getMultiFactorResolver(auth, err as MultiFactorError);
          const verifier = new RecaptchaVerifier(auth, "recaptcha", {
            size: "invisible",
          });
          const id = await new PhoneAuthProvider(auth).verifyPhoneNumber(
            { multiFactorHint: next.hints[0], session: next.session },
            verifier,
          );
          setResolver(next);
          setVerification(id);
        } catch (mfaError) {
          setError((mfaError as Error).message);
        }
      } else setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="login-screen">
      <div className="login-art">
        <span className="brand-icon">C</span>
        <p className="eyebrow">CONFERENCE OPERATIONS & NETWORKING</p>
        <h1>
          A thoughtful space
          <br />
          for every detail.
        </h1>
        <p>
          People. Programme. Possibilities.
          <br />
          Bring your conference together with CONE.
        </p>
        <div className="orbit orbit-one" />
        <div className="orbit orbit-two" />
        <span className="login-art-footer">
          21st Uttarakhand State Science & Technology Congress
        </span>
      </div>
      <div className="login-form">
        <span className="tag">
          <ShieldCheck size={15} /> ADMINISTRATIVE WORKSPACE
        </span>
        <h1>Welcome back.</h1>
        <p className="subtitle">Sign in to manage your conference.</p>
        {!configured && (
          <div className="setup-note">
            <strong>Connect your Firebase project</strong>
            <p>
              Copy <code>.env.example</code> to <code>.env</code>, add your
              Firebase web configuration and server credentials, then restart.
              See the dashboard README for setup.
            </p>
          </div>
        )}
        <Message error={error || externalError} />
        {externalError.includes("second factor") && <MfaEnrollment />}
        <form onSubmit={submit}>
          {resolver ? (
            <label>
              Verification code
              <input name="code" autoComplete="one-time-code" required />
            </label>
          ) : (
            <>
              <label>
                Email address
                <input
                  type="email"
                  name="email"
                  placeholder="you@organization.org"
                  autoComplete="username"
                  required
                />
              </label>
              <label>
                Password
                <input
                  type="password"
                  name="password"
                  autoComplete="current-password"
                  required
                  minLength={6}
                />
              </label>
            </>
          )}
          <button className="primary wide" disabled={!configured || busy}>
            {busy ? <LoaderCircle className="spin" size={18} /> : null}
            {resolver ? "Verify & continue" : "Sign in to workspace"}
            <ArrowUpRight size={18} />
          </button>
        </form>
        <button
          className="text-button"
          onClick={async () => {
            const email = window.prompt("Your Firebase account email");
            if (email && auth)
              try {
                await sendPasswordResetEmail(auth, email);
                setNote("If this account exists, a reset email will be sent.");
              } catch (e) {
                setError((e as Error).message);
              }
          }}
        >
          Forgot your password?
        </button>
        {note && <p className="success">{note}</p>}
        <div id="recaptcha" />
        <p className="login-hint">
          Access is assigned by your Super Admin. Your mobile app sign-in
          remains unchanged.
        </p>
      </div>
    </div>
  );
}
function Overview({ navigate }: { navigate: (p: string) => void }) {
  const [data, setData] = useState<Record<string, unknown> | null>(null),
    [error, setError] = useState("");
  useEffect(() => {
    request("/overview")
      .then(setData)
      .catch((e) => setError(e.message));
  }, []);
  if (error) return <Message error={error} />;
  if (!data) return <Loading />;
  const metrics = [
    {
      label: "Total registrations",
      value: data.registrations,
      icon: Users,
      color: "green",
      note: "Excludes demo records",
    },
    {
      label: "Confirmed participants",
      value: data.confirmed,
      icon: CheckCircle2,
      color: "blue",
      note: "Ready for the conference",
    },
    {
      label: "Presenters",
      value: data.presenters,
      icon: GraduationCap,
      color: "purple",
      note: "Scientific contributions",
    },
    {
      label: "Meals served",
      value: data.mealsServed,
      icon: Utensils,
      color: "orange",
      note: "Recorded redemptions",
    },
  ];
  const roles = data.byRole as Record<string, number>;
  const max = Math.max(1, ...Object.values(roles));
  return (
    <>
      <div className="welcome-banner">
        <div>
          <span className="tag light">YOUR CONFERENCE COMMAND CENTRE</span>
          <h2>
            Good things happen
            <br />
            when everything connects.
          </h2>
          <p>Keep your people informed and your operations in sync.</p>
          <button
            className="banner-button"
            onClick={() => navigate("participants")}
          >
            Manage participants <ArrowUpRight size={16} />
          </button>
        </div>
        <div className="banner-graphic">
          <div className="graphic-circle">
            <GraduationCap size={54} />
          </div>
          <span className="graphic-label">
            USSTC <strong>21</strong>
          </span>
        </div>
      </div>
      <div className="metrics">
        {metrics.map((m) => (
          <div className="metric" key={m.label}>
            <div className="metric-top">
              <span>{m.label}</span>
              <span className={`metric-icon ${m.color}`}>
                <m.icon size={19} />
              </span>
            </div>
            <strong>{label(m.value)}</strong>
            <small>{m.note}</small>
          </div>
        ))}
      </div>
      <div className="overview-grid">
        <section className="panel">
          <div className="panel-heading">
            <div>
              <h2>People at the centre</h2>
              <p>Registration breakdown by conference role</p>
            </div>
            <Users size={20} />
          </div>
          <div className="bars">
            {Object.entries(roles).map(([role, count]) => (
              <div className="bar-row" key={role}>
                <span>{role === "organiser" ? "Organizer" : role}</span>
                <div className="bar-track">
                  <div style={{ width: `${(count / max) * 100}%` }} />
                </div>
                <strong>{count}</strong>
              </div>
            ))}
          </div>
        </section>
        <section className="panel">
          <div className="panel-heading">
            <div>
              <h2>Make your next move</h2>
              <p>A few things you can take care of today</p>
            </div>
          </div>
          {[
            {
              title: "Bring your participants in",
              text: "Validate and import an Excel workbook.",
              icon: FileSpreadsheet,
              page: "imports",
            },
            {
              title: "Shape the programme",
              text: "Organize sessions and presentation times.",
              icon: CalendarDays,
              page: "sessions",
            },
            {
              title: "Keep everyone connected",
              text: "Check your email delivery setup.",
              icon: Mail,
              page: "email",
            },
          ].map((i) => (
            <button
              className="quick-action"
              key={i.page}
              onClick={() => navigate(i.page)}
            >
              <span className="quick-icon">
                <i.icon size={20} />
              </span>
              <span>
                <strong>{i.title}</strong>
                <small>{i.text}</small>
              </span>
              <ChevronRight size={18} />
            </button>
          ))}
        </section>
      </div>
      <section className="panel">
        <div className="panel-heading">
          <div>
            <h2>Recent import activity</h2>
            <p>Your latest participant data updates</p>
          </div>
          <button className="text-button" onClick={() => navigate("imports")}>
            View imports <ArrowUpRight size={15} />
          </button>
        </div>
        {(data.recentImports as Row[]).length ? (
          <Table
            rows={data.recentImports as Row[]}
            columns={["fileName", "status", "total", "createdAt"]}
          />
        ) : (
          <Empty
            title="A fresh start"
            description="Your workbook imports will appear here once you upload them."
          />
        )}
      </section>
    </>
  );
}
function Table({
  rows,
  columns,
  onEdit,
}: {
  rows: Row[];
  columns: string[];
  onEdit?: (r: Row) => void;
}) {
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            {columns.map((c) => (
              <th key={c}>{c.replace(/([A-Z])/g, " $1")}</th>
            ))}
            {onEdit && (
              <th>
                <span className="sr-only">Actions</span>
              </th>
            )}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id}>
              {columns.map((c) => (
                <td key={c}>
                  {[
                    "status",
                    "registrationStatus",
                    "role",
                    "accessRole",
                  ].includes(c) ? (
                    <span
                      className={`badge ${row[c] === "confirmed" || row[c] === "active" || row[c] === "completed" ? "positive" : ""}`}
                    >
                      {label(row[c])}
                    </span>
                  ) : (
                    <span
                      className={
                        c === "fullName" || c === "title" ? "cell-name" : ""
                      }
                    >
                      {label(row[c])}
                    </span>
                  )}
                </td>
              ))}
              {onEdit && (
                <td>
                  <button className="text-button" onClick={() => onEdit(row)}>
                    Edit <ChevronRight size={14} />
                  </button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
function Records({ module }: { module: Module }) {
  const [rows, setRows] = useState<Row[]>([]),
    [loading, setLoading] = useState(true),
    [error, setError] = useState(""),
    [search, setSearch] = useState(""),
    [selected, setSelected] = useState<Row | null | undefined>(),
    [next, setNext] = useState<string | null>(null);
  async function load(after?: string) {
    setLoading(true);
    setError("");
    try {
      const data = await request<{ rows: Row[]; next: string | null }>(
        `/records/${module}${after ? `?after=${encodeURIComponent(after)}` : ""}`,
      );
      setRows((old) => (after ? [...old, ...data.rows] : data.rows));
      setNext(data.next);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => {
    void load();
  }, [module]);
  const columns =
    module === "participants"
      ? ["fullName", "email", "role", "registrationStatus"]
      : module === "users"
        ? ["fullName", "email", "accessRole", "status"]
        : fields[module].slice(0, 4).map((f) => f.key);
  const filtered = rows.filter((r) =>
    Object.values(r).some((v) =>
      String(v).toLowerCase().includes(search.toLowerCase()),
    ),
  );
  return (
    <>
      <Message error={error} />
      <section className="panel">
        <div className="toolbar">
          <div className="search">
            <Search size={18} />
            <input
              aria-label="Search loaded records"
              placeholder="Search loaded records…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <span className="record-count">{rows.length} loaded</span>
          {module === "participants" && (
            <button
              className="secondary"
              onClick={async () => {
                try {
                  download(
                    await request<Blob>("/reports/participants"),
                    "cone-registrations.xlsx",
                  );
                } catch (e) {
                  setError((e as Error).message);
                }
              }}
            >
              <Download size={16} />
              Export
            </button>
          )}
          <button className="primary" onClick={() => setSelected(null)}>
            <Plus size={17} />
            Add{" "}
            {module === "users"
              ? "user"
              : module === "participants"
                ? "participant"
                : module === "sessions"
                  ? "session"
                  : module === "disciplines"
                    ? "discipline"
                    : module === "submissions"
                      ? "paper"
                      : module === "meals"
                        ? "meal"
                        : "record"}
          </button>
        </div>
        {module === "users" && (
          <p className="inline-note">
            Users must already have a Firebase Authentication account. Dashboard
            access is separate from their conference role.
          </p>
        )}
        {loading && !rows.length ? (
          <Loading />
        ) : filtered.length ? (
          <Table rows={filtered} columns={columns} onEdit={setSelected} />
        ) : (
          <Empty />
        )}
        {next && (
          <button
            className="secondary load-more"
            disabled={loading}
            onClick={() => void load(next)}
          >
            Load more
          </button>
        )}
      </section>
      {module === "users" && <InviteUser />}
      {module === "meals" && <CouponTools />}
      {selected !== undefined && (
        <Editor
          module={module}
          row={selected}
          close={() => setSelected(undefined)}
          saved={() => {
            setSelected(undefined);
            void load();
          }}
        />
      )}
    </>
  );
}
function Editor({
  module,
  row,
  close,
  saved,
}: {
  module: Module;
  row: Row | null;
  close: () => void;
  saved: () => void;
}) {
  const [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const form = new FormData(e.currentTarget);
    const data = Object.fromEntries(
      fields[module].map((f) => [
        f.key,
        f.type === "number"
          ? Number(form.get(f.key) || 0)
          : form.get(f.key) || "",
      ]),
    );
    try {
      await request(`/records/${module}`, {
        method: "POST",
        body: JSON.stringify({ id: row?.id, version: row?.version || 1, data }),
      });
      saved();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="modal-backdrop">
      <section
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="editor-title"
      >
        <div className="panel-heading">
          <div>
            <p className="eyebrow">CONFERENCE DATA</p>
            <h2 id="editor-title">{row ? "Edit record" : "Create a record"}</h2>
          </div>
          <button className="icon-button" onClick={close} aria-label="Close">
            <X />
          </button>
        </div>
        <Message error={error} />
        <form onSubmit={submit}>
          <div className="form-grid">
            {fields[module].map((f) => (
              <label
                key={f.key}
                className={f.type === "textarea" ? "full-width" : ""}
              >
                {f.label}
                {f.required && " *"}
                {f.options ? (
                  <select
                    name={f.key}
                    defaultValue={String(row?.[f.key] ?? f.options[0])}
                  >
                    {f.options.map((o) => (
                      <option key={o} value={o}>
                        {o || "Not set"}
                      </option>
                    ))}
                  </select>
                ) : f.type === "textarea" ? (
                  <textarea
                    name={f.key}
                    required={f.required}
                    defaultValue={String(row?.[f.key] || "")}
                    rows={4}
                  />
                ) : (
                  <input
                    name={f.key}
                    type={f.type || "text"}
                    required={f.required}
                    min={f.type === "number" ? 0 : undefined}
                    defaultValue={String(row?.[f.key] || "")}
                    readOnly={Boolean(row && f.key === "email")}
                  />
                )}
              </label>
            ))}
          </div>
          <div className="form-actions">
            <button type="button" className="secondary" onClick={close}>
              Cancel
            </button>
            {row && !["staff", "submissions"].includes(module) && (
              <button
                type="button"
                className="secondary"
                disabled={busy}
                onClick={async () => {
                  if (
                    !window.confirm(
                      "Archive this record? Its history will be retained.",
                    )
                  )
                    return;
                  setBusy(true);
                  try {
                    await request(
                      `/records/${module}/${encodeURIComponent(row.id)}/archive`,
                      { method: "POST" },
                    );
                    saved();
                  } catch (e) {
                    setError((e as Error).message);
                  } finally {
                    setBusy(false);
                  }
                }}
              >
                Archive record
              </button>
            )}
            <button className="primary" disabled={busy}>
              {busy ? "Saving…" : "Save record"}
            </button>
          </div>
        </form>
      </section>
    </div>
  );
}
function download(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function Media() {
  const [rows, setRows] = useState<Row[]>([]),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  async function load() {
    try {
      setRows(await request<Row[]>("/media"));
    } catch (e) {
      setError((e as Error).message);
    }
  }
  useEffect(() => {
    void load();
  }, []);
  return (
    <>
      <Message error={error} />
      <section className="panel">
        <div className="panel-heading">
          <div>
            <h2>A home for your conference visuals</h2>
            <p>
              Private images stored on your VPS. JPEG, PNG or WebP · up to 5 MB.
            </p>
          </div>
        </div>
        <form
          className="toolbar"
          onSubmit={async (e) => {
            e.preventDefault();
            setBusy(true);
            setError("");
            const form = e.currentTarget;
            try {
              await request("/media", {
                method: "POST",
                body: new FormData(form),
              });
              form.reset();
              await load();
            } catch (e) {
              setError((e as Error).message);
            } finally {
              setBusy(false);
            }
          }}
        >
          <input
            type="file"
            name="file"
            accept="image/jpeg,image/png,image/webp"
            required
          />
          <button className="primary" disabled={busy}>
            <Upload size={17} />
            {busy ? "Uploading…" : "Upload image"}
          </button>
        </form>
        {rows.length ? (
          <div className="media-grid">
            {rows.map((row) => (
              <MediaCard
                key={row.id}
                row={row}
                onArchived={() => void load()}
              />
            ))}
          </div>
        ) : (
          <Empty
            title="Your media library is ready"
            description="Upload conference branding and other images to your private VPS storage."
          />
        )}
      </section>
    </>
  );
}
function MediaCard({ row, onArchived }: { row: Row; onArchived: () => void }) {
  const [url, setUrl] = useState("");
  const [error, setError] = useState("");
  useEffect(() => {
    let active = true;
    let objectUrl = "";
    request<Blob>(`/media/${row.id}/file`)
      .then((blob) => {
        objectUrl = URL.createObjectURL(blob);
        if (active) setUrl(objectUrl);
      })
      .catch(() => {});
    return () => {
      active = false;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [row.id]);
  return (
    <div className="media-card">
      {url ? <img src={url} alt={String(row.name)} /> : <Image size={28} />}
      <strong>{label(row.name)}</strong>
      <small>Private · VPS storage</small>
      <button
        className="text-button"
        onClick={async () => {
          if (
            !window.confirm(
              "Archive this image? Its file will be retained for recovery.",
            )
          )
            return;
          try {
            await request(`/media/${row.id}/archive`, { method: "POST" });
            onArchived();
          } catch (e) {
            setError((e as Error).message);
          }
        }}
      >
        Archive image
      </button>
      {error && <small role="alert">{error}</small>}
    </div>
  );
}
function Email() {
  const [error, setError] = useState(""),
    [note, setNote] = useState(""),
    [busy, setBusy] = useState(false);
  return (
    <section className="panel narrow">
      <span className="feature-icon">
        <Mail size={26} />
      </span>
      <h2>Make sure your message arrives.</h2>
      <p className="subtitle">
        Send a connection test using the server's SMTP settings.
      </p>
      <Message error={error} />
      {note && <p className="success">{note}</p>}
      <form
        onSubmit={async (e) => {
          e.preventDefault();
          setBusy(true);
          setError("");
          try {
            await request("/email/test", {
              method: "POST",
              body: JSON.stringify({
                email: new FormData(e.currentTarget).get("email"),
              }),
            });
            setNote("Test email sent successfully.");
          } catch (e) {
            setError((e as Error).message);
          } finally {
            setBusy(false);
          }
        }}
      >
        <label>
          Test recipient
          <input
            type="email"
            name="email"
            required
            placeholder="you@organization.org"
          />
        </label>
        <button className="primary" disabled={busy}>
          {busy ? "Sending…" : "Send test email"}
          <ArrowUpRight size={17} />
        </button>
      </form>
      <p className="inline-note">
        SMTP credentials are configured on the server. Firebase continues to
        handle the mobile app's sign-in emails.
      </p>
    </section>
  );
}
function SettingsPage() {
  const [data, setData] = useState<Record<string, unknown> | null>(null),
    [error, setError] = useState(""),
    [note, setNote] = useState("");
  useEffect(() => {
    request("/settings")
      .then(setData)
      .catch((e) => setError(e.message));
  }, []);
  return (
    <section className="panel narrow">
      <h2>Application controls</h2>
      <p className="subtitle">Global settings available to the Super Admin.</p>
      <Message error={error} />
      {note && <p className="success">{note}</p>}
      {data ? (
        <>
          <form
            onSubmit={async (e) => {
              e.preventDefault();
              const form = new FormData(e.currentTarget);
              try {
                await request("/settings", {
                  method: "PUT",
                  body: JSON.stringify({
                    maintenanceMode: form.has("maintenanceMode"),
                    registrationOpen: form.has("registrationOpen"),
                  }),
                });
                setNote("Settings saved.");
              } catch (e) {
                setError((e as Error).message);
              }
            }}
          >
            <label className="checkbox">
              <input
                type="checkbox"
                name="maintenanceMode"
                defaultChecked={Boolean(data.maintenanceMode)}
              />
              Maintenance mode
            </label>
            <label className="checkbox">
              <input
                type="checkbox"
                name="registrationOpen"
                defaultChecked={Boolean(data.registrationOpen)}
              />
              Registration open
            </label>
            <button className="primary">Save settings</button>
          </form>
          <p className="inline-note">
            URLs, storage directories, and Firebase configuration are managed
            through the deployment environment. Configure mail in Email / SMTP.
            Maintenance mode applies to this dashboard; registration-open is
            metadata for future public/mobile integration.
          </p>
          <pre>
            {JSON.stringify(
              { smtp: data.smtp, mfaRequired: data.mfaRequired },
              null,
              2,
            )}
          </pre>
        </>
      ) : (
        !error && <Loading />
      )}
    </section>
  );
}
function Analysis() {
  const [health, setHealth] = useState<Record<string, unknown> | null>(null),
    [error, setError] = useState("");
  useEffect(() => {
    request("/system-health")
      .then(setHealth)
      .catch((e) => setError(e.message));
  }, []);
  return (
    <>
      <Message error={error} />
      <section className="panel">
        <h2>System health</h2>
        <p className="subtitle">Live checks from your administrative API.</p>
        {health ? (
          <div className="health-grid">
            {Object.entries(health).map(([key, value]) => (
              <div className="health-item" key={key}>
                <Activity size={20} />
                <strong>{key}</strong>
                <span>{label(value)}</span>
              </div>
            ))}
          </div>
        ) : (
          !error && <Loading />
        )}
      </section>
      <LogTable endpoint="analysis" />
      <p className="inline-note">
        Analysis reports are written by trusted CI or operations tooling.
        Missing reports do not imply passing checks. The dashboard does not
        execute shell commands.
      </p>
    </>
  );
}
function LogTable({
  endpoint,
}: {
  endpoint: "audit" | "analysis" | "imports" | "redemptions";
}) {
  const [rows, setRows] = useState<Row[] | null>(null),
    [error, setError] = useState("");
  useEffect(() => {
    request<Row[]>(`/${endpoint}`)
      .then(setRows)
      .catch((e) => setError(e.message));
  }, [endpoint]);
  const columns =
    endpoint === "audit"
      ? ["actorName", "action", "target", "createdAt"]
      : endpoint === "analysis"
        ? ["tool", "result", "buildId", "generatedAt"]
        : endpoint === "imports"
          ? ["fileName", "status", "total", "createdAt"]
          : ["couponId", "participantEmail", "meal", "day"];
  return (
    <section className="panel">
      <div className="panel-heading">
        <h2>
          {endpoint === "audit"
            ? "Activity history"
            : endpoint === "analysis"
              ? "Code analysis reports"
              : endpoint === "imports"
                ? "Import history"
                : "Meal redemption history"}
        </h2>
        <span className="record-count">Up to 100 records</span>
      </div>
      <Message error={error} />
      {rows ? (
        rows.length ? (
          <Table rows={rows} columns={columns} />
        ) : (
          <Empty
            title="No activity recorded"
            description="Records will appear here when operations are completed."
          />
        )
      ) : (
        !error && <Loading />
      )}
    </section>
  );
}
function CouponTools() {
  const [error, setError] = useState(""),
    [note, setNote] = useState("");
  return (
    <section className="panel">
      <h2>Issue meal coupons</h2>
      <p className="subtitle">
        Issue configured meal slots to a confirmed participant. Already-issued
        slots are preserved.
      </p>
      <Message error={error} />
      {note && <p className="success">{note}</p>}
      <form
        className="toolbar"
        onSubmit={async (e) => {
          e.preventDefault();
          try {
            const result = await request<{ issued: number }>("/coupons/issue", {
              method: "POST",
              body: JSON.stringify({
                email: new FormData(e.currentTarget).get("email"),
              }),
            });
            setNote(`${result.issued} new coupons issued.`);
          } catch (e) {
            setError((e as Error).message);
          }
        }}
      >
        <input
          type="email"
          name="email"
          placeholder="Participant email"
          aria-label="Participant email"
          required
        />
        <button className="primary">Issue coupons</button>
      </form>
    </section>
  );
}
function Redemptions() {
  const [error, setError] = useState(""),
    [note, setNote] = useState("");
  return (
    <>
      <section className="panel narrow">
        <h2>Meal desk</h2>
        <p className="subtitle">
          Enter the coupon ID from the participant's QR code.
        </p>
        <Message error={error} />
        {note && <p className="success">{note}</p>}
        <form
          onSubmit={async (e) => {
            e.preventDefault();
            setError("");
            setNote("");
            try {
              await request("/coupons/redeem", {
                method: "POST",
                body: JSON.stringify({
                  couponId: new FormData(e.currentTarget).get("couponId"),
                }),
              });
              setNote("Meal served. This coupon is now used.");
            } catch (e) {
              setError((e as Error).message);
            }
          }}
        >
          <label>
            Coupon ID
            <input name="couponId" required />
          </label>
          <button className="primary">Mark as served</button>
        </form>
      </section>
      <LogTable endpoint="redemptions" />
    </>
  );
}
