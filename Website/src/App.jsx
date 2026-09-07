import { useRef, useState } from "react";
import {
  ArrowRightIcon,
  CameraIcon,
  CaretDownIcon,
  EyeIcon,
  LockKeyIcon,
  PlugIcon,
  ShieldCheckIcon,
  XIcon,
} from "@phosphor-icons/react";
import "@fontsource-variable/outfit";

const components = [
  {
    name: "Amplifier",
    summary: "Likely powers the speakers",
    x: 49,
    y: 55,
    purpose:
      "This appears to be an integrated amplifier. It takes sound from a connected source and boosts it to drive the speakers.",
    evidence:
      "Inferred from the front-panel controls and its position between the speakers. The rear connections are outside the photo.",
    impact:
      "The connected speakers would likely go silent. Disconnecting audio cables while equipment is on may also cause a loud pop.",
  },
  {
    name: "Left speaker",
    summary: "Likely plays the left audio channel",
    x: 20,
    y: 19,
    purpose:
      "This appears to be a passive bookshelf speaker. It turns the amplifier’s electrical signal into sound.",
    evidence:
      "The speaker drivers are visible. Its connection to the amplifier is inferred because the cable endpoints are not shown.",
    impact:
      "Sound would likely stop from this speaker. The other speaker might continue playing, depending on how the system is wired.",
  },
  {
    name: "Right speaker",
    summary: "Likely plays the right audio channel",
    x: 80,
    y: 19,
    purpose:
      "This appears to be the second speaker in a stereo pair. Together, the speakers create a left-to-right sound image.",
    evidence:
      "Its matching cabinet and drivers are visible. The source and rear wiring cannot be confirmed from this angle.",
    impact:
      "Sound would likely stop from this speaker. Check with the person responsible for the setup before changing its connections.",
  },
];

function Brand() {
  return (
    <a className="brand" href="#top" aria-label="Don't Unplug That home">
      <PlugIcon
        size={43}
        weight="light"
        className="brand-icon"
        aria-hidden="true"
      />
      <span>Don’t Unplug That</span>
    </a>
  );
}

export function App() {
  const captionRef = useRef(null);
  const [selected, setSelected] = useState(0);
  const [expanded, setExpanded] = useState(false);
  const [showImpact, setShowImpact] = useState(false);
  const item = components[selected];
  function selectItem(index) {
    setSelected(index);
    setExpanded(true);
    setShowImpact(false);
  }
  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <div className="page" id="top">
        <header className="header">
          <Brand />
          <nav aria-label="Main navigation">
            <a href="#how-it-works">How it works</a>
            <a href="#privacy">Privacy</a>
          </nav>
        </header>
        <main id="main">
          <section className="hero" aria-labelledby="hero-title">
            <h1 id="hero-title">
              From “what is this?”
              <br />
              to “now I get it.”
            </h1>
            <p className="hero-description">
              A clearer picture of the things around you.
              <br className="desktop-break" /> Photograph a setup and understand
              how it fits together.
            </p>
            <a className="button primary hero-cta" href="#how-it-works">
              See how it works
            </a>
            <figure className="setup-figure">
              <div className="setup-photo">
                <img
                  src="/images/living-room-audio.webp"
                  alt="A cream amplifier between two walnut speakers on an oak shelf, with plants and a pale blue wall."
                  width="2172"
                  height="724"
                  fetchPriority="high"
                />
                {components.map((component, index) => (
                  <button
                    key={component.name}
                    className={`annotation ${selected === index ? "selected" : ""}`}
                    style={{ left: `${component.x}%`, top: `${component.y}%` }}
                    aria-label={`Explore ${component.name.toLowerCase()}`}
                    aria-pressed={selected === index}
                    aria-controls="example-details"
                    onClick={() => selectItem(index)}
                  >
                    <span>{index + 1}</span>
                  </button>
                ))}
              </div>
              <figcaption>
                <button
                  ref={captionRef}
                  className="caption-button"
                  aria-expanded={expanded}
                  aria-controls="example-details"
                  onClick={() => setExpanded(!expanded)}
                >
                  <span className="number">{selected + 1}</span>
                  <strong>{item.name}</strong>
                  <span className="caption-dot" aria-hidden="true">
                    ·
                  </span>
                  <span className="caption-summary">{item.summary}</span>
                  <CaretDownIcon
                    size={20}
                    className={expanded ? "rotated" : ""}
                    aria-hidden="true"
                  />
                </button>
                <span className="example-label">Interactive example</span>
              </figcaption>
            </figure>
            <div
              id="example-details"
              hidden={!expanded}
              className="example-details"
            >
              <div className="detail-heading">
                <div>
                  <span className="eyebrow">Example guide</span>
                  <h2>{item.name}</h2>
                </div>
                <button
                  className="icon-button"
                  aria-label="Close example details"
                  onClick={() => {
                    setExpanded(false);
                    captionRef.current?.focus();
                  }}
                >
                  <XIcon size={22} />
                </button>
              </div>
              <div className="detail-columns">
                <div>
                  <h3>What it likely does</h3>
                  <p>{item.purpose}</p>
                </div>
                <div>
                  <h3>
                    <EyeIcon size={19} aria-hidden="true" /> What we can tell
                  </h3>
                  <p>{item.evidence}</p>
                </div>
              </div>
              <button
                className="button primary"
                aria-expanded={showImpact}
                aria-controls="unplugging-impact"
                onClick={() => setShowImpact(!showImpact)}
              >
                {showImpact ? "Hide unplugging impact" : "What if I unplug it?"}
                <CaretDownIcon
                  size={18}
                  className={showImpact ? "rotated" : ""}
                  aria-hidden="true"
                />
              </button>
              <p
                id="unplugging-impact"
                hidden={!showImpact}
                className="impact"
                role="status"
              >
                {item.impact}
              </p>
              <p className="safety-note">
                <ShieldCheckIcon size={21} aria-hidden="true" />
                <span>
                  A photo cannot confirm it is safe to disconnect. Stop if
                  anything is hot, damaged, wet, or sparking, and ask a
                  qualified technician.
                </span>
              </p>
              <p className="demo-note">
                Illustrative example using a generated photo, not a live
                analysis.
              </p>
            </div>
            <a href="#privacy" className="privacy-link">
              <LockKeyIcon size={22} aria-hidden="true" />
              Photo analysis stays on your device.
            </a>
          </section>
          <section
            id="how-it-works"
            className="how-section"
            aria-labelledby="how-title"
          >
            <div className="section-intro">
              <span className="eyebrow">A little less guesswork</span>
              <h2 id="how-title">Start with what you see.</h2>
              <p>
                From the living room to the equipment cupboard, a few photos can
                make an unfamiliar setup easier to understand.
              </p>
            </div>
            <div className="how-layout">
              <div className="welcome-photo">
                <img
                  src="/images/welcome-setup.jpg"
                  alt="A fabric speaker, a green plant and a coiled cable against a light blue background."
                  width="1200"
                  height="960"
                  loading="lazy"
                />
                <span>One photo is a good place to start.</span>
              </div>
              <ol className="steps">
                <li>
                  <CameraIcon size={28} aria-hidden="true" />
                  <div>
                    <h3>Take a photo.</h3>
                    <p>
                      Capture the whole setup. Add up to three angles to show
                      labels and both ends of important cables.
                    </p>
                  </div>
                </li>
                <li>
                  <EyeIcon size={28} aria-hidden="true" />
                  <div>
                    <h3>Get to know the parts.</h3>
                    <p>
                      Tap a numbered pin to see what an item likely does, with a
                      clear distinction between what’s visible and what’s
                      inferred.
                    </p>
                  </div>
                </li>
                <li>
                  <PlugIcon size={28} aria-hidden="true" />
                  <div>
                    <h3>Understand what could change.</h3>
                    <p>
                      See what disconnecting an item might affect, where there’s
                      uncertainty, and when to ask for help.
                    </p>
                  </div>
                </li>
              </ol>
            </div>
            <a className="text-link" href="#top" onClick={() => selectItem(0)}>
              Try the example above
              <ArrowRightIcon size={20} aria-hidden="true" />
            </a>
          </section>
          <section
            id="privacy"
            className="privacy-section"
            aria-labelledby="privacy-title"
          >
            <LockKeyIcon
              className="privacy-icon"
              size={38}
              weight="light"
              aria-hidden="true"
            />
            <div>
              <span className="eyebrow">Your space. Your photos.</span>
              <h2 id="privacy-title">Clarity, with a little privacy.</h2>
              <p>
                The app analyzes photos on your device. Your guides stay there
                too, unless you choose to turn on sync.
              </p>
              <p>
                Optional sync stores private, resized photo copies with photo
                metadata removed, along with your guides. Sync is not end-to-end
                encrypted.
              </p>
              <p className="muted">
                On-device analysis requires a supported device and model.
                Availability varies by platform.
              </p>
            </div>
          </section>
        </main>
        <footer>
          <Brand />
          <span>A clearer picture. A more considered next step.</span>
          <a href="#top">
            Back to top
            <ArrowRightIcon size={16} aria-hidden="true" />
          </a>
        </footer>
      </div>
    </>
  );
}
