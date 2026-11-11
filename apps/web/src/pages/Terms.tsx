import { Link } from 'react-router-dom'
import { InfoLayout } from '../features/landing/InfoLayout'

export default function Terms() {
  return (
    <InfoLayout
      title="Terms of Service"
      description="The terms for using Mission Control: your account, acceptable use, connected services and apps, availability, and how to leave."
    >
      <header className="lp-info-head">
        <h1>Terms of Service.</h1>
        <p>Plain terms for using Mission Control. Last updated: November 11, 2026.</p>
      </header>

      <section className="lp-info-section" id="terms" data-info-reveal>
        <p>
          Mission Control (“we”, “us”) is operated by Nighthawk Labs at mission-control.nighthawklabs.org. By creating an
          account or using Mission Control, including through a connector or plugin in another app such as Claude or
          ChatGPT, you agree to these terms. If you do not agree, do not use it.
        </p>

        <h3>Your account</h3>
        <p>
          You need an account to use Mission Control. Keep your sign-in secure and give accurate information. You are
          responsible for what happens under your account, including what your companions do on your behalf. You must be at
          least 13 years old.
        </p>

        <h3>What Mission Control does</h3>
        <p>
          Mission Control gives you personal assistants (“companions”) with long-term memory and access to the services you
          connect. A companion uses AI models to answer and act on your requests. AI output can be wrong or incomplete;
          check anything important before you rely on it.
        </p>

        <h3>Connected services, apps and connectors</h3>
        <p>
          You choose which services a companion can reach, such as a Google account, and you can disconnect any of them at
          any time. Your use of a connected service is also subject to that service’s own terms. When you add Mission
          Control to another app (for example the Claude or ChatGPT connectors), that app’s terms apply to your use of that
          app, and these terms apply to Mission Control. What a companion remembers or does through a connector is stored
          in your account like anything else you give it.
        </p>

        <h3>Your content</h3>
        <p>
          You keep ownership of what you give Mission Control: messages, goals, memories, files and data from services you
          connect. You give us permission to store, process and send it to the model providers and services involved, only
          as needed to run Mission Control for you. See the <Link to="/privacy">privacy policy</Link> for how data is
          handled.
        </p>

        <h3>Acceptable use</h3>
        <ul className="lp-info-list">
          <li>Do not use Mission Control to break the law or to harm, harass or deceive others.</li>
          <li>Do not attempt to access other accounts or data, or to disrupt, probe or overload the service.</li>
          <li>Do not use it to build or train a competing model, or to resell access without our agreement.</li>
          <li>Follow the terms of every model provider and connected service your companion uses.</li>
        </ul>
        <p>We may suspend or limit an account that breaks these rules or puts the service or other people at risk.</p>

        <h3>Availability and changes</h3>
        <p>
          Mission Control is provided as it is available. Some features are in development and may change, be limited or
          be removed, and we promise no release dates. We may update the service or these terms. We will post changes on
          this page and update the date above; continuing to use Mission Control after a change means you accept it.
        </p>

        <h3>Ending your use</h3>
        <p>
          You can stop at any time and disconnect any service. To delete your account and its data, email us and we will
          delete it within 30 days, as described in the privacy policy. We may end or suspend access if you break these
          terms.
        </p>

        <h3>No warranty, and limits on liability</h3>
        <p>
          Mission Control is provided “as is”, without warranties of any kind, to the fullest extent the law allows. We do
          not guarantee it will be uninterrupted, error-free or fit for a particular purpose. To the fullest extent the
          law allows, Nighthawk Labs is not liable for indirect, incidental or consequential damages, or for loss of data,
          profits or goodwill, arising from your use of Mission Control, and our total liability for any claim is limited
          to the greater of the amount you paid us in the 12 months before the claim and USD 50. Nothing here limits
          liability that cannot be limited by law.
        </p>

        <h3>Contact</h3>
        <p>
          Questions about these terms:{' '}
          <a href="mailto:abishekkumar92@gmail.com">abishekkumar92@gmail.com</a>. For help using Mission Control, see{' '}
          <Link to="/support">Support</Link>.
        </p>
      </section>
    </InfoLayout>
  )
}
