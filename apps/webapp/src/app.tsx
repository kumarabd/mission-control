import { Link, Route, Routes, useParams } from "react-router";
import { usePresentationStore } from "./store/presentation-store";
import "./styles.css";

export function App() {
  const isSourcePanelOpen = usePresentationStore((state) => state.isSourcePanelOpen);
  const setSourcePanelOpen = usePresentationStore((state) => state.setSourcePanelOpen);

  return (
    <div className="app-shell">
      <header className="app-header">
        <Link className="wordmark" to="/">Mission Control</Link>
        <button
          aria-expanded={isSourcePanelOpen}
          aria-controls="source-panel"
          onClick={() => setSourcePanelOpen(!isSourcePanelOpen)}
          type="button"
        >
          Sources
        </button>
      </header>
      {isSourcePanelOpen ? (
        <aside id="source-panel" className="source-panel">
          Source configuration will be available once the PSS runtime contract is accepted.
        </aside>
      ) : null}
      <main>
        <Routes>
          <Route path="/" element={<PortfolioBoard />} />
          <Route path="/projects/:projectId" element={<ProjectDetail />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </main>
    </div>
  );
}

function PortfolioBoard() {
  return (
    <section aria-labelledby="portfolio-title" className="view">
      <p className="eyebrow">Portfolio</p>
      <h1 id="portfolio-title">Projects at a glance</h1>
      <p>The project adapter and representative fixtures are the next implementation package.</p>
    </section>
  );
}

function ProjectDetail() {
  const { projectId } = useParams();

  return (
    <section aria-labelledby="project-title" className="view">
      <p className="eyebrow">Project detail</p>
      <h1 id="project-title">{projectId}</h1>
      <p>Project data will remain traceable to its canonical sources.</p>
      <Link to="/">Back to portfolio</Link>
    </section>
  );
}

function NotFound() {
  return (
    <section aria-labelledby="not-found-title" className="view">
      <h1 id="not-found-title">Page not found</h1>
      <Link to="/">Return to portfolio</Link>
    </section>
  );
}
