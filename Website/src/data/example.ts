export const components = [
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
