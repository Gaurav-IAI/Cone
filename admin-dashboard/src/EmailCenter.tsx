import { useEffect, useState, type ReactNode, type FormEvent } from "react";
import { Mail, Plus, Send } from "lucide-react";
import { request } from "./firebase";
import SmtpSettings from "./SmtpSettings";
type Template = { id: string; name: string; subject: string; body: string };
type Job = {
  id: string;
  recipient: string;
  status: string;
  attempts?: number;
  createdAt: string;
};
export default function EmailCenter({
  children,
  isSuperAdmin = false,
}: {
  children: ReactNode;
  isSuperAdmin?: boolean;
}) {
  const [templates, setTemplates] = useState<Template[]>([]),
    [jobs, setJobs] = useState<Job[]>([]),
    [error, setError] = useState(""),
    [note, setNote] = useState(""),
    [busy, setBusy] = useState(false),
    [revision, setRevision] = useState(0);
  useEffect(() => {
    Promise.all([
      request<Template[]>("/email/templates"),
      request<Job[]>("/email/jobs"),
    ])
      .then(([a, b]) => {
        setTemplates(a);
        setJobs(b);
      })
      .catch((e) => setError(e.message));
  }, [revision]);
  async function create(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    setBusy(true);
    setError("");
    try {
      await request("/email/templates", {
        method: "POST",
        body: JSON.stringify(Object.fromEntries(new FormData(form))),
      });
      form.reset();
      setRevision((r) => r + 1);
      setNote("Template saved.");
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  async function queue(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    setBusy(true);
    setError("");
    try {
      const values = new FormData(form);
      const recipients = String(values.get("recipients"))
        .split(/[\n,;]/)
        .map((v) => v.trim())
        .filter(Boolean);
      await request("/email/queue", {
        method: "POST",
        body: JSON.stringify({
          templateId: values.get("templateId"),
          recipients,
          requestId: crypto.randomUUID(),
        }),
      });
      form.reset();
      setRevision((r) => r + 1);
      setNote("Messages queued. Run the email worker to deliver them.");
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      {error && (
        <div className="message" role="alert">
          {error}
        </div>
      )}
      {note && <p className="success">{note}</p>}
      <div className="overview-grid">
        <section className="panel">
          <span className="feature-icon">
            <Mail size={24} />
          </span>
          <h2>A message worth sending.</h2>
          <p className="subtitle">
            Save a plain-text template. Use {"{{name}}"} for the participant's
            name.
          </p>
          <form onSubmit={create}>
            <label>
              Template name
              <input name="name" required maxLength={100} />
            </label>
            <label>
              Subject
              <input name="subject" required maxLength={150} />
            </label>
            <label>
              Message
              <textarea
                name="body"
                required
                rows={6}
                maxLength={10000}
                placeholder="Hello {{name}},"
              />
            </label>
            <button className="primary" disabled={busy}>
              <Plus size={16} />
              Save template
            </button>
          </form>
        </section>
        <section className="panel">
          <span className="feature-icon">
            <Send size={24} />
          </span>
          <h2>Keep your people in the loop.</h2>
          <p className="subtitle">
            Queue messages for up to 50 registered participants at a time.
          </p>
          <form onSubmit={queue}>
            <label>
              Template
              <select name="templateId" required>
                <option value="">Select a template</option>
                {templates.map((t) => (
                  <option value={t.id} key={t.id}>
                    {t.name} · {t.subject}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Recipient emails
              <textarea
                name="recipients"
                required
                rows={6}
                placeholder="One email per line, or separated by commas"
              />
            </label>
            <button className="primary" disabled={busy || !templates.length}>
              <Send size={16} />
              Queue notifications
            </button>
          </form>
          <p className="inline-note">
            Messages are delivered by the separate server worker, with bounded
            retries and recorded delivery status.
          </p>
        </section>
      </div>
      {isSuperAdmin && <SmtpSettings />}
      {children}
      <section className="panel">
        <div className="panel-heading">
          <h2>Delivery activity</h2>
          <button
            className="text-button"
            onClick={() => setRevision((r) => r + 1)}
          >
            Refresh
          </button>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Recipient</th>
                <th>Status</th>
                <th>Attempts</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {jobs.map((j) => (
                <tr key={j.id}>
                  <td>{j.recipient}</td>
                  <td>
                    <span
                      className={`badge ${j.status === "sent" ? "positive" : ""}`}
                    >
                      {j.status}
                    </span>
                  </td>
                  <td>{j.attempts || 1}</td>
                  <td>{j.createdAt}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!jobs.length && (
            <p className="inline-note">No email delivery attempts yet.</p>
          )}
        </div>
      </section>
    </>
  );
}
