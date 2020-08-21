import React, { useRef, useEffect } from 'react';
import Image from './image';
import useI18n from '../hooks/use-i18n';
import PageHeading from './page-heading';

/**
 * @typedef SubmissionInterstitialProps
 *
 * @prop {boolean=} autoFocus Whether to focus heading immediately on mount.
 */

/**
 * @param {SubmissionInterstitialProps} props Props object.
 */
function SubmissionInterstitial({ autoFocus = false }) {
  const { t } = useI18n();
  const headingRef = useRef(/** @type {?HTMLHeadingElement} */ (null));
  useEffect(() => {
    if (autoFocus) {
      headingRef.current?.focus();
    }
  }, []);

  return (
    <div>
      <Image assetPath="id-card.svg" alt="" width="216" height="116" className="margin-bottom-4" />
      <PageHeading ref={headingRef} tabIndex={-1}>
        {t('doc_auth.headings.interstitial')}
      </PageHeading>
      <p className="margin-top-4">{t('doc_auth.info.interstitial_eta')}</p>
      <p>{t('doc_auth.info.interstitial_thanks')}</p>
    </div>
  );
}

export default SubmissionInterstitial;
