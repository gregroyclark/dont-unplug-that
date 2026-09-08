import { components } from '../data/example';

const caption = document.querySelector<HTMLButtonElement>('#example-caption')!;
const details = document.querySelector<HTMLElement>('#example-details')!;
const impact = document.querySelector<HTMLElement>('#unplugging-impact')!;
const impactToggle = document.querySelector<HTMLButtonElement>('#impact-toggle')!;
const pins = document.querySelectorAll<HTMLButtonElement>('[data-component]');

function setExpanded(expanded: boolean) {
  details.hidden = !expanded;
  caption.setAttribute('aria-expanded', String(expanded));
  caption.querySelector('svg')?.classList.toggle('rotated', expanded);
}

function setImpact(expanded: boolean) {
  impact.hidden = !expanded;
  impactToggle.setAttribute('aria-expanded', String(expanded));
  impactToggle.querySelector('[data-impact-label]')!.textContent = expanded
    ? 'Hide unplugging impact' : 'What if I unplug it?';
  impactToggle.querySelector('svg')?.classList.toggle('rotated', expanded);
}

function selectItem(index: number) {
  const item = components[index];
  if (!item) return;
  pins.forEach((pin, pinIndex) => {
    pin.classList.toggle('selected', pinIndex === index);
    pin.setAttribute('aria-pressed', String(pinIndex === index));
  });
  caption.querySelector('[data-number]')!.textContent = String(index + 1);
  document.querySelectorAll('[data-name]').forEach(node => { node.textContent = item.name; });
  caption.querySelector('[data-summary]')!.textContent = item.summary;
  details.querySelector('[data-purpose]')!.textContent = item.purpose;
  details.querySelector('[data-evidence]')!.textContent = item.evidence;
  impact.textContent = item.impact;
  setImpact(false);
  setExpanded(true);
}

pins.forEach(pin => pin.addEventListener('click', () => selectItem(Number(pin.dataset.component))));
caption.addEventListener('click', () => setExpanded(details.hidden));
impactToggle.addEventListener('click', () => setImpact(impact.hidden));
details.querySelector<HTMLButtonElement>('[aria-label="Close example details"]')!
  .addEventListener('click', () => { setExpanded(false); caption.focus(); });
document.querySelector('[data-try-example]')!.addEventListener('click', () => selectItem(0));
